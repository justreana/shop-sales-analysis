CREATE OR REPLACE VIEW v_sales AS
SELECT o.order_id,
       o.order_date,
       o.status,
       c.client_id,
       c.first_name || ' ' || c.last_name AS client_name,
       ci.name                            AS city,
       cat.name                           AS category,
       p.product_id,
       p.name                             AS product,
       p.price,
       oi.quantity,
       oi.quantity * p.price              AS revenue
FROM orders o
JOIN clients     c   ON c.client_id    = o.client_id
JOIN cities      ci  ON ci.city_id     = c.city_id
JOIN order_items oi  ON oi.order_id    = o.order_id
JOIN products    p   ON p.product_id   = oi.product_id
JOIN categories  cat ON cat.category_id = p.category_id;

-- 1. Какие заказы и кем оформлены в ноябре–декабре 2025 и доставлены? Самые свежие сверху.
SELECT o.order_id, o.order_date, c.client_id, c.first_name, c.last_name
FROM orders o
JOIN clients c ON c.client_id = o.client_id
WHERE o.status = 'delivered'
  AND o.order_date BETWEEN DATE '2025-11-01' AND DATE '2025-12-31'
ORDER BY o.order_date DESC;

--2. Сколько заказов и какая выручка по месяцам?
SELECT TRIM(TO_CHAR(DATE_TRUNC('month', o.order_date), 'Month')) AS month_name,
       COUNT(o.order_id) AS orders_cnt,
       SUM(p.amount)     AS revenue
FROM orders o
JOIN payments p ON p.order_id = o.order_id
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY DATE_TRUNC('month', o.order_date);

-- 3. Какую выручку приносит каждая категория и сколько штук продано?
select sum(oi.quantity * p.price) , c."name", count(o.order_id ) from order_items oi 
join products p on p.product_id = oi.product_id 
join categories c on c.category_id =p.category_id
join orders o on o.order_id = oi.order_id 
where o.status <> 'cancelled' 
group by c."name" 
order by sum desc

--4. топ-5 товаров по количеству проданных штук.
select p."name", sum(oi.quantity) from order_items oi 
join products p on p.product_id = oi.product_id 
join orders o on o.order_id = oi.order_id 
where o.status <> 'cancelled'
group by "name" 
order by sum desc
limit 5
 
--5. клиенты, которые ни разу не заказывали.
select c.first_name ||' '|| c.last_name as full_name  from clients c 
left join orders o on o.client_id  =c.client_id 
where o.order_id is null

--6.в каких городах больше 40 оплаченных заказов и какой там средний чек.
select round(avg(p.amount), 2), c2."name", count(o.order_id ) from payments p 
join orders o on o.order_id = p.order_id 
join clients c on c.client_id  = o.client_id 
join cities c2 on c2.city_id =c.city_id 
group by c2."name" 
having count(o.order_id ) > 40 
order by round(avg(p.amount), 2) desc

--7. какие оплаты выше среднего чека по магазину.
select p.payment_id, p.amount, p.order_id  from payments p 
where p.amount > (select AVG(p.amount ) from payments p )
order by amount desc
limit 20

--8. доля выручки каждой категории и накопленная доля (ABC-кривая).
with category_revenue as (select sum(oi.quantity * p.price) as revenuee , c."name" as categoryy from order_items oi 
join products p on p.product_id = oi.product_id 
join categories c on c.category_id =p.category_id
join orders o on o.order_id = oi.order_id 
where o.status <> 'cancelled' 
group by c."name" 
order by revenuee  desc)
select revenuee , categoryy , round (revenuee / sum(revenuee) over ()* 100, 1) as dolya, round((sum(revenuee) over(order by revenuee desc) / sum(revenuee ) over()) * 100, 1) as dolya_nakop  from category_revenue 
order by revenuee desc 

--9. топ-3 товара в каждой категории по выручке.
with product_revenue as(
select p."name" as product, sum(p.price * oi.quantity) as revenue, c."name" as category from order_items oi 
join products p on p.product_id = oi.product_id
join categories c on c.category_id =p.category_id 
join orders o on o.order_id = oi.order_id 
where status <> 'cancelled'
group by category, product), ranked as (select category , product , revenue, 
rank() over (partition by category order by revenue desc) as rnk from product_revenue )
select category , product, revenue, rnk  from ranked 
where rnk <= 3
order by category , rnk 

--10.нарастающий итог и рост к прошлому месяцу
with monthly as (select sum(vs.price * vs.quantity) as revenue, 
date_trunc('month', vs.order_date ) as month
from v_sales vs 
where status <> 'cancelled'
group by month)
select revenue, sum(revenue) over (order by month),
round((revenue - lag(revenue) over (order by month)) / lag(revenue) over (order by month) * 100, 1), month
from monthly
order by month

--11. какая доля клиентов купила повторно
with client_orders as (select o.client_id , count(*) as orders_cnt from orders o
where o.status <> 'cancelled'
group by o.client_id 
)
select count(*) as all_who_buy,
COUNT(*) FILTER (WHERE orders_cnt > 1) as all_who_buy_more_than_one,
round(( 100.0 * COUNT(*) FILTER (WHERE orders_cnt > 1) / count(*)), 1) as dolya  from client_orders 
