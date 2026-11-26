-- Заполнение базы shop данными.
-- Запускать после 01_schema.sql. Скрипт можно запускать повторно.
-- Закономерности в данных:
--   1) в выходные заказов примерно в 2 раза больше, чем в будни;
--   2) в ноябре–декабре сезонный рост (x1.6), летом спад (x0.8);
--   3) цены сильно различаются по категориям (электроника дороже книг в десятки раз);
--   4) часть клиентов покупает часто, часть один раз, часть не покупала ни разу (клиенты 281–300).

SELECT setseed(0.42);  -- фиксируем случайность: данные одинаковые при каждом запуске

TRUNCATE payments, order_items, orders, products, clients, categories, cities RESTART IDENTITY CASCADE;

-- Города (12)
INSERT INTO cities (name) VALUES
    ('Москва'), ('Санкт-Петербург'), ('Казань'), ('Новосибирск'),
    ('Екатеринбург'), ('Нижний Новгород'), ('Краснодар'), ('Самара'),
    ('Ростов-на-Дону'), ('Уфа'), ('Воронеж'), ('Пермь');

-- Категории (8)
INSERT INTO categories (name) VALUES
    ('Электроника'), ('Бытовая техника'), ('Одежда'), ('Обувь'),
    ('Книги'), ('Спорт'), ('Красота'), ('Дом и сад');

-- Товары (40): по 5 в каждой категории, цены зависят от категории
INSERT INTO products (category_id, name, price) VALUES
    (1, 'Смартфон',            32990.00),
    (1, 'Ноутбук',             64990.00),
    (1, 'Наушники беспроводные', 7490.00),
    (1, 'Планшет',             27990.00),
    (1, 'Умные часы',          12990.00),
    (2, 'Пылесос',             14990.00),
    (2, 'Микроволновая печь',   8990.00),
    (2, 'Кофемашина',          24990.00),
    (2, 'Блендер',              4490.00),
    (2, 'Электрочайник',        2490.00),
    (3, 'Футболка',             1290.00),
    (3, 'Джинсы',               3990.00),
    (3, 'Куртка',               8990.00),
    (3, 'Свитер',               3490.00),
    (3, 'Платье',               4990.00),
    (4, 'Кроссовки',            6990.00),
    (4, 'Ботинки зимние',       7990.00),
    (4, 'Туфли',                5490.00),
    (4, 'Сандалии',             2990.00),
    (4, 'Кеды',                 3990.00),
    (5, 'Роман',                 590.00),
    (5, 'Учебник',               990.00),
    (5, 'Детектив',              490.00),
    (5, 'Комикс',                690.00),
    (5, 'Кулинарная книга',      890.00),
    (6, 'Гантели',              2990.00),
    (6, 'Йога-коврик',          1490.00),
    (6, 'Велосипед',           24990.00),
    (6, 'Футбольный мяч',       1990.00),
    (6, 'Палатка',              6990.00),
    (7, 'Крем для лица',         890.00),
    (7, 'Шампунь',               490.00),
    (7, 'Духи',                 3990.00),
    (7, 'Помада',                990.00),
    (7, 'Набор для ухода',      2490.00),
    (8, 'Набор посуды',         3990.00),
    (8, 'Лампа настольная',     1490.00),
    (8, 'Плед',                 1990.00),
    (8, 'Садовый инвентарь',    2790.00),
    (8, 'Органайзер',            790.00);

-- Клиенты (300). Клиенты 281–300 ничего не заказывают (пригодится для LEFT JOIN).
INSERT INTO clients (first_name, last_name, email, city_id, registered_on)
SELECT
    CASE WHEN g % 2 = 0
         THEN (ARRAY['Анна','Мария','Елена','Ольга','Наталья','Ирина','Татьяна','Светлана'])[1 + (g / 2) % 8]
         ELSE (ARRAY['Иван','Алексей','Дмитрий','Сергей','Андрей','Михаил','Николай','Павел'])[1 + (g / 2) % 8]
    END,
    CASE WHEN g % 2 = 0
         THEN (ARRAY['Иванова','Петрова','Смирнова','Кузнецова','Попова','Васильева','Соколова','Михайлова','Новикова','Фёдорова'])[1 + (g * 3) % 10]
         ELSE (ARRAY['Иванов','Петров','Смирнов','Кузнецов','Попов','Васильев','Соколов','Михайлов','Новиков','Фёдоров'])[1 + (g * 3) % 10]
    END,
    'user' || g || '@example.com',
    1 + floor(12 * power(random(), 1.5))::int,        -- больше клиентов из первых городов (Москва, Санкт-Петербург)
    DATE '2024-01-01' + (random() * 360)::int          -- все зарегистрированы до начала 2025 года
FROM generate_series(1, 300) AS g;

-- Вес каждого дня 2025 года: выходные x2, ноябрь–декабрь x1.6, лето x0.8
DROP TABLE IF EXISTS day_w;
CREATE TEMP TABLE day_w AS
SELECT d,
       SUM(w) OVER (ORDER BY d) AS cum,
       SUM(w) OVER ()           AS total
FROM (
    SELECT d::date AS d,
           (CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN 2.0 ELSE 1.0 END)
         * (CASE WHEN EXTRACT(MONTH FROM d) IN (11, 12) THEN 1.6
                 WHEN EXTRACT(MONTH FROM d) IN (6, 7, 8) THEN 0.8
                 ELSE 1.0 END) AS w
    FROM generate_series(DATE '2025-01-01', DATE '2025-12-31', INTERVAL '1 day') AS d
) s;

-- Заказы (600): дата выбирается пропорционально весу дня, клиент — со смещением к «постоянным»
INSERT INTO orders (client_id, order_date, status)
WITH r AS MATERIALIZED (
    SELECT g,
           1 + floor(280 * power(random(), 1.5))::int AS client_id,  -- клиенты 1..280, чаще маленькие id
           random() AS u_date,
           random() AS u_status
    FROM generate_series(1, 600) AS g
)
SELECT r.client_id,
       dd.d,
       CASE WHEN dd.d > DATE '2025-12-20' AND r.u_status < 0.5 THEN 'new'
            WHEN r.u_status < 0.08 THEN 'cancelled'
            ELSE 'delivered' END
FROM r
CROSS JOIN LATERAL (
    SELECT d FROM day_w
    WHERE cum >= r.u_date * (SELECT MAX(total) FROM day_w)
    ORDER BY cum
    LIMIT 1
) AS dd
ORDER BY dd.d, r.g;

-- Позиции заказов: от 1 до 3 разных товаров в заказе
INSERT INTO order_items (order_id, product_id, quantity)
SELECT o.order_id,
       p.product_id,
       CASE WHEN p.price < 1500 THEN 1 + floor(random() * 3)::int   -- дешёвое берут по несколько штук
            ELSE 1 + floor(random() * 1.3)::int END
FROM orders o
CROSS JOIN LATERAL (SELECT 1 + floor(random() * 3 + o.order_id * 0)::int AS n) k  -- o.order_id нужен, чтобы n считалось для каждого заказа заново
CROSS JOIN LATERAL (
    SELECT product_id, price FROM products
    ORDER BY md5(o.order_id::text || '-' || product_id::text)   -- «случайный» порядок товаров для каждого заказа свой
    LIMIT k.n
) p;

-- Оплаты: по одной на каждый неотменённый заказ, сумма = сумма позиций
INSERT INTO payments (order_id, method, amount, paid_on)
SELECT t.order_id,
       CASE WHEN t.r < 0.55 THEN 'card' WHEN t.r < 0.85 THEN 'sbp' ELSE 'cash' END,
       t.amount,
       t.order_date + (t.r2 * 3)::int
FROM (
    SELECT o.order_id, o.order_date,
           SUM(oi.quantity * p.price) AS amount,
           random() AS r,
           random() AS r2
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.order_date
) t;

-- Проверка: сколько строк в каждой таблице
SELECT 'cities' AS tbl, COUNT(*) FROM cities
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'clients', COUNT(*) FROM clients
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments;
