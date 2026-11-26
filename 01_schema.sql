-- Тема: Интернет-магазин
-- Уровень: 3 (цель — 10 баллов)
-- База данных: shop

-- Удаляем таблицы, если скрипт запускается повторно (сначала дочерние)
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

-- Справочник городов
CREATE TABLE cities (
    city_id   SERIAL PRIMARY KEY,
    name      VARCHAR(80) NOT NULL UNIQUE
);

-- Справочник категорий товаров
CREATE TABLE categories (
    category_id  SERIAL PRIMARY KEY,
    name         VARCHAR(100) NOT NULL UNIQUE
);

-- Клиенты
CREATE TABLE clients (
    client_id      SERIAL PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(120) NOT NULL UNIQUE,
    city_id        INTEGER      NOT NULL REFERENCES cities (city_id),
    registered_on  DATE         NOT NULL
);

-- Товары
CREATE TABLE products (
    product_id   SERIAL PRIMARY KEY,
    category_id  INTEGER       NOT NULL REFERENCES categories (category_id),
    name         VARCHAR(150)  NOT NULL,
    price        NUMERIC(10, 2) NOT NULL CHECK (price > 0)
);

-- Заказы (главная таблица)
CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    client_id   INTEGER     NOT NULL REFERENCES clients (client_id),
    order_date  DATE        NOT NULL,
    status      VARCHAR(20) NOT NULL CHECK (status IN ('new', 'delivered', 'cancelled'))
);

-- Позиции заказа: связующая таблица «заказы — товары» (связь многие ко многим)
CREATE TABLE order_items (
    order_item_id  SERIAL PRIMARY KEY,
    order_id       INTEGER NOT NULL REFERENCES orders (order_id),
    product_id     INTEGER NOT NULL REFERENCES products (product_id),
    quantity       INTEGER NOT NULL CHECK (quantity > 0),
    UNIQUE (order_id, product_id)  -- один товар — одна строка в заказе
);

-- Оплаты: одна оплата на один заказ
CREATE TABLE payments (
    payment_id  SERIAL PRIMARY KEY,
    order_id    INTEGER        NOT NULL UNIQUE REFERENCES orders (order_id),
    method      VARCHAR(20)    NOT NULL CHECK (method IN ('card', 'cash', 'sbp')),
    amount      NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    paid_on     DATE           NOT NULL
);
