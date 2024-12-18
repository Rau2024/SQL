create database customers_transactions;

UPDATE customers SET Gender = NUll WHERE Gender = '';
UPDATE customers SET Age = NULL WHERE Age = '';
ALTER TABLE customers MODIFY AGE INT NULL;

SELECT * FROM Customers;

create table transactions
(
date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL (10,2)
);



LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM transactions;

## 1. список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе 
# без пропусков за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, 
# средняя сумма покупок за месяц, количество всех операций по клиенту за период;


# 1. Выборка клиентов с непрерывной историей покупок: 
SELECT ID_client
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY ID_client
HAVING COUNT(DISTINCT MONTH(date_new)) = 12;

# 2. Средний чек за период:

SELECT
    ID_client,
    AVG(Sum_payment) AS avg_check
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY ID_client;


#3. Средняя сумма покупок за месяц:

SELECT
    ID_client,
    AVG(MONTHLY_SUM) AS avg_monthly_spend
FROM (
    SELECT
        ID_client,
        YEAR(date_new) AS year,
        MONTH(date_new) AS month,
        SUM(Sum_payment) AS MONTHLY_SUM
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, YEAR(date_new), MONTH(date_new)
) AS monthly_sums
GROUP BY ID_client;

# 4. Количество операций по клиенту за период: 

SELECT
    ID_client,
    COUNT(*) AS total_transactions
FROM transactions
WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY ID_client;


# Итоговый запрос:

SELECT 
    t.ID_client,
    AVG(t.Sum_payment) AS avg_check,
    AVG(m.MONTHLY_SUM) AS avg_monthly_spend,
    COUNT(t.Id_check) AS total_transactions
FROM transactions t
LEFT JOIN (
    SELECT
        ID_client,
        YEAR(date_new) AS year,
        MONTH(date_new) AS month,
        SUM(Sum_payment) AS MONTHLY_SUM
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, YEAR(date_new), MONTH(date_new)
) m ON t.ID_client = m.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY t.ID_client
HAVING COUNT(DISTINCT MONTH(t.date_new)) = 12;


## 2. информацию в разрезе месяцев:
# средняя сумма чека в месяц;
# среднее количество операций в месяц;
# среднее количество клиентов, которые совершали операции;
# долю от общего количества операций за год и долю в месяц от общей суммы операций;

# 1. Средняя сумма чека в месяц:
SELECT
    YEAR(date_new) AS year,
    MONTH(date_new) AS month,
    AVG(Sum_payment) AS avg_check_amount
FROM transactions
GROUP BY year, month
ORDER BY year, month;

# 2. Среднее количество операций в месяц:
SELECT
    YEAR(date_new) AS year,
    MONTH(date_new) AS month,
    COUNT(*) / COUNT(DISTINCT MONTH(date_new)) AS avg_transactions_per_month
FROM transactions
GROUP BY year, month
ORDER BY year, month;

# 3. Среднее количество клиентов, которые совершали операции в месяц:
SELECT
    YEAR(date_new) AS year,
    MONTH(date_new) AS month,
    COUNT(DISTINCT ID_client) AS avg_clients_per_month
FROM transactions
GROUP BY year, month
ORDER BY year, month;

# 4. Доля от общего количества операций за год и доля в месяц от общей суммы операций:

# Доля от общего количества операций за год:
SELECT
    YEAR(t.date_new) AS year,
    MONTH(t.date_new) AS month,
    COUNT(*) / total_operations_year.total_operations AS operations_share
FROM transactions t
JOIN (
    SELECT YEAR(date_new) AS year, COUNT(*) AS total_operations
    FROM transactions
    GROUP BY YEAR(date_new)
) total_operations_year
ON YEAR(t.date_new) = total_operations_year.year
GROUP BY YEAR(t.date_new), MONTH(t.date_new), total_operations_year.total_operations
ORDER BY year, month;


# Доля в месяц от общей суммы операций:
SELECT
    YEAR(t.date_new) AS year,
    MONTH(t.date_new) AS month,
    SUM(t.Sum_payment) / total_year_sum.total_sum AS monthly_amount_share
FROM transactions t
JOIN (
    SELECT YEAR(date_new) AS year, SUM(Sum_payment) AS total_sum
    FROM transactions
    GROUP BY YEAR(date_new)
) total_year_sum
ON YEAR(t.date_new) = total_year_sum.year
GROUP BY YEAR(t.date_new), MONTH(t.date_new), total_year_sum.total_sum
ORDER BY year, month;

# 5. вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

SELECT
    YEAR(t.date_new) AS year,
    MONTH(t.date_new) AS month,
    c.Gender,
    COUNT(*) AS total_count,
    SUM(t.Sum_payment) AS total_sum,
    (SUM(t.Sum_payment) / total_month_sum.total_sum) * 100 AS gender_share_percentage
FROM transactions t
JOIN customers c ON t.ID_client = c.Id_client  -- Соединяем с таблицей customers по ID клиента
JOIN (
    SELECT YEAR(date_new) AS year, MONTH(date_new) AS month, SUM(Sum_payment) AS total_sum
    FROM transactions
    GROUP BY YEAR(date_new), MONTH(date_new)
) total_month_sum
ON YEAR(t.date_new) = total_month_sum.year AND MONTH(t.date_new) = total_month_sum.month
GROUP BY YEAR(t.date_new), MONTH(t.date_new), c.Gender, total_month_sum.total_sum
ORDER BY year, month, FIELD(c.Gender, 'M', 'F', 'NA');



## 3. возрастные группы клиентов с шагом 10 лет и отдельно клиентов, 
# у которых нет данной информации, с параметрами сумма и количество операций за весь период, 
# и поквартально - средние показатели и %.


SELECT 
  CASE
    WHEN Age IS NULL THEN 'Без информации'
    WHEN Age BETWEEN 0 AND 9 THEN '0-9 лет'
    WHEN Age BETWEEN 10 AND 19 THEN '10-19 лет'
    WHEN Age BETWEEN 20 AND 29 THEN '20-29 лет'
    WHEN Age BETWEEN 30 AND 39 THEN '30-39 лет'
    WHEN Age BETWEEN 40 AND 49 THEN '40-49 лет'
    WHEN Age BETWEEN 50 AND 59 THEN '50-59 лет'
    WHEN Age BETWEEN 60 AND 69 THEN '60-69 лет'
    WHEN Age BETWEEN 70 AND 79 THEN '70-79 лет'
    WHEN Age >= 80 THEN '80 и старше'
  END AS Age_Group,
  
  COUNT(t.Id_check) AS Operation_Count,
  SUM(t.Sum_payment) AS Total_Amount,

  -- Поквартальные средние значения
  AVG(CASE WHEN QUARTER(t.date_new) = 1 THEN t.Sum_payment ELSE NULL END) AS Q1_Avg_Payment,
  AVG(CASE WHEN QUARTER(t.date_new) = 2 THEN t.Sum_payment ELSE NULL END) AS Q2_Avg_Payment,
  AVG(CASE WHEN QUARTER(t.date_new) = 3 THEN t.Sum_payment ELSE NULL END) AS Q3_Avg_Payment,
  AVG(CASE WHEN QUARTER(t.date_new) = 4 THEN t.Sum_payment ELSE NULL END) AS Q4_Avg_Payment,

  -- Процент от общего количества операций в группе
  (COUNT(t.Id_check) / (SELECT COUNT(*) FROM transactions)) * 100 AS Operation_Percentage

FROM customers c
JOIN transactions t ON c.Id_client = t.ID_client
GROUP BY Age_Group;

