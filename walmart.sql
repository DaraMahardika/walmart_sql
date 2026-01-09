select * from `customer.walmart`;

--customer segmentation
--based on age, gender, purchase pattern

-- recency
SELECT
Customer_ID,
MAX(Purchase_Date) last_order_date,
DATE_DIFF(CURRENT_DATE(), MAX(Purchase_Date), DAY) recency
FROM
`customer.walmart`
GROUP BY
1
ORDER BY
recency;

-- Frequent Shoppers – Customers who return often.
SELECT
CASE
  WHEN Age BETWEEN 13 AND 28 THEN 'Gen Z'
  WHEN Age BETWEEN 29 AND 44 THEN 'Gen Millenial'
  WHEN Age BETWEEN 45 AND 60 THEN 'Gen X'
  ELSE 'UNKNOWN'
END AS generation,
COUNT(*) frequency,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),2) AS percentage
FROM
`customer.walmart`
WHERE
Repeat_Customer = TRUE
GROUP BY
generation
ORDER BY
frequency DESC;
-- Gen Millenial	9375	37.14 Gen X	9341	37.0 Gen Z	6528	25.86

-- High-Value Customers – Those who make large purchases.
SELECT
CASE
  WHEN Age BETWEEN 13 AND 28 THEN 'Gen Z'
  WHEN Age BETWEEN 29 AND 44 THEN 'Gen Millenial'
  WHEN Age BETWEEN 45 AND 60 THEN 'Gen X'
  ELSE 'UNKNOWN'
END AS generation,
ROUND(SUM(Purchase_Amount),2) total_purchase
FROM
`customer.walmart`
WHERE
Discount_Applied = TRUE
GROUP BY
generation
ORDER BY
total_purchase DESC;
-- Gen X	2384120.72  Gen Millenial	2334331.97  Gen Z	1666334.66

--Discount-Driven Buyers – Customers who shop mainly during sales.
SELECT
CASE
  WHEN Age BETWEEN 13 AND 28 THEN 'Gen Z'
  WHEN Age BETWEEN 29 AND 44 THEN 'Gen Millenial'
  WHEN Age BETWEEN 45 AND 60 THEN 'Gen X'
  ELSE 'UNKNOWN'
END AS generation,
COUNT(CASE WHEN Discount_Applied = TRUE THEN 1 END) total_discount,
COUNT(*) frequency,
ROUND(COUNT(CASE WHEN Discount_Applied = TRUE THEN 1 END) *100 / COUNT(*),2) percentage
FROM
`customer.walmart`
GROUP BY
generation
HAVING
percentage > 50
ORDER BY
percentage DESC;
-- Gen X	9310	18514	50.29 Gen Z	6494	12939	50.19

--Impulse Shoppers – Customers who make frequent small purchases.
WITH CUST AS(
  SELECT
  CASE
  WHEN Age BETWEEN 13 AND 28 THEN 'Gen Z'
  WHEN Age BETWEEN 29 AND 44 THEN 'Gen Millenial'
  WHEN Age BETWEEN 45 AND 60 THEN 'Gen X'
  ELSE 'UNKNOWN'
  END AS generation,
  COUNT(*) frequency,
  ROUND(AVG(Purchase_Amount),2) avg_purchase
  FROM
  `customer.walmart`
  GROUP BY
  generation
  ORDER BY
  frequency,
  avg_purchase
),A AS(
  SELECT
  AVG(frequency) avg_transaction,
  AVG(avg_purchase) avg_avg_purchase
  FROM
  CUST
)
SELECT
c.generation,
c.frequency,
c.avg_purchase
FROM
CUST c,
A
WHERE
c.frequency > A.avg_transaction
AND
c.avg_purchase < A.avg_avg_purchase
ORDER BY
c.frequency,
c.avg_purchase;
--Gen X	18514	255.46

--

-- used discount voucher based on age group and gender
SELECT
CASE
  WHEN Age BETWEEN 13 AND 28 THEN 'Gen Z'
  WHEN Age BETWEEN 29 AND 44 THEN 'Gen Millenial'
  WHEN Age BETWEEN 45 AND 60 THEN 'Gen X'
  ELSE 'UNKNOWN'
END AS generation,
Gender,
ROUND(SUM(Purchase_Amount),2) revenue
FROM
`customer.walmart`
WHERE
Discount_Applied = TRUE
AND
Repeat_Customer = TRUE
GROUP BY generation, Gender
ORDER BY generation,revenue DESC;


--SALES FORECASTING
-- Identify seasonal shopping patterns.
--MoM
WITH monthly_sales AS (
  SELECT
    Category,
    EXTRACT(YEAR FROM Purchase_Date) AS year,
    EXTRACT(MONTH FROM Purchase_Date) AS month,
    SUM(Purchase_Amount) AS month_sales
  FROM
    `customer.walmart`
  GROUP BY
    1, 2, 3
)
SELECT
  Category,
  year,
  month,
  month_sales,
  prev_month,
  ROUND((month_sales - prev_month) * 100 / prev_month, 2) AS MoM
FROM (
  SELECT
    Category,
    year,
    month,
    month_sales,
    LAG(month_sales) OVER (PARTITION BY Category ORDER BY year, month) AS prev_month
  FROM
    monthly_sales
) AS prev_month_data
WHERE
  prev_month IS NOT NULL
ORDER BY
  Category,
  year,
  month;

--plus YoY
WITH monthly_sales AS (
  SELECT
    Category,
    EXTRACT(YEAR FROM Purchase_Date) AS year,
    EXTRACT(MONTH FROM Purchase_Date) AS month,
    SUM(Purchase_Amount) AS month_sales
  FROM
    `customer.walmart`
  GROUP BY
    1, 2, 3
),
growth_data AS (
  SELECT
    Category,
    year,
    month,
    month_sales,
    LAG(month_sales) OVER (PARTITION BY Category ORDER BY year, month) AS prev_month,
    LAG(month_sales, 12) OVER (PARTITION BY Category ORDER BY year, month) AS prev_year
  FROM
    monthly_sales
)
SELECT
  Category,
  year,
  month,
  month_sales,
  ROUND((month_sales - prev_month) * 100 / prev_month, 2) AS MoM_Growth,
  ROUND((month_sales - prev_year) * 100 / prev_year, 2) AS YoY_Growth
FROM
  growth_data
WHERE
  prev_month IS NOT NULL OR prev_year IS NOT NULL
ORDER BY
  Category,
  year,
  month;

  -- volatilitas harian (moving average)
  SELECT
  Purchase_Date,
  ROUND(SUM(Purchase_Amount),1) Daily_sales,
  ROUND(AVG(SUM(Purchase_Amount)) OVER(
    ORDER BY Purchase_Date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ),2) weekly_moving
  FROM
  `customer.walmart`
  GROUP BY
  Purchase_Date;

--seasonality analyst
SELECT
FORMAT_DATE('%A',Purchase_Date) Day_name,
ROUND(AVG(Purchase_Amount),2) sales
FROM
`customer.walmart`
GROUP BY
Day_name
ORDER BY
sales DESC
;

--categori specific trend
SELECT
DATE_TRUNC(Purchase_Date, MONTH) Month,
Category,
ROUND(SUM(Purchase_Amount),2) total_sales
FROM
`customer.walmart`
GROUP BY
1,2
ORDER BY
1
;

--cumulative sales (YTD)
SELECT
Purchase_Date,
Purchase_Amount,
SUM(Purchase_Amount) OVER(ORDER BY Purchase_Date) total_sales
FROM
`customer.walmart`
;


--PRODUCT PERFORMANCE
--categories generate the most revenue.
SELECT
Category,
ROUND(SUM(Purchase_Amount),2) revenue
FROM
`customer.walmart`
GROUP BY
Category
ORDER BY
revenue DESC
;

-- worst product
WITH ProductSales AS (
  SELECT
    Product_Name,
    SUM(CASE WHEN Discount_Applied = TRUE THEN 1 ELSE 0 END) AS discounted_sales,
    COUNT(Purchase_Amount) AS total_sales
  FROM
    `customer.walmart`
  GROUP BY
    Product_Name
)
SELECT
  Product_Name,
  discounted_sales,
  total_sales,
  ROUND((discounted_sales * 100.0 / total_sales),2) AS percentage_discount_sales
FROM
  ProductSales
WHERE
  total_sales > 10 -- Filter produk dengan penjualan yang cukup signifikan
ORDER BY
  percentage_discount_sales DESC, total_sales ASC;

--semua pakai diskon engga
SELECT
    product_name,
    SUM(Purchase_Amount) AS total_revenue
FROM
    `customer.walmart`
GROUP BY
    product_name
ORDER BY
    total_revenue ASC
;

SELECT
    product_name,
    ROUND(AVG(Purchase_Amount),2) AS average_price
FROM
    `customer.walmart`
GROUP BY
    product_name
ORDER BY
    average_price
;


-- rating vs revenue
SELECT 
Product_Name,
ROUND(SUM(Purchase_Amount),2) revenue,
ROUND(AVG(Rating),1) avg_rating,
COUNT(*) total_transaction
FROM
`customer.walmart`
GROUP BY
Product_Name
HAVING 
SUM(Purchase_Amount) > 1000 -- Filter produk yang signifikan
ORDER BY avg_rating DESC, revenue ASC
;

--discount sensitivity
SELECT 
Product_Name,
ROUND(AVG(CASE WHEN Discount_Applied = FALSE THEN Purchase_Amount END),2) Sales_No_Discount,
ROUND(AVG(CASE WHEN Discount_Applied = TRUE THEN Purchase_Amount END),2) Sales_With_Discount,
ROUND(AVG(CASE WHEN Discount_Applied = TRUE THEN Purchase_Amount END) - 
AVG(CASE WHEN Discount_Applied = FALSE THEN Purchase_Amount END),2) Sales_Uplift
FROM
`customer.walmart`
GROUP BY 1
ORDER BY
Sales_Uplift DESC
;

-- pareto sales
WITH product_sales AS(
  SELECT
  Product_Name,
  SUM(Purchase_Amount) revenue
  FROM
  `customer.walmart`
  GROUP BY
  1
)
SELECT
Product_Name,
revenue,
ROUND(SUM(revenue) OVER(ORDER BY revenue DESC) / SUM(revenue) OVER(), 2) cumulative
FROM
product_sales
ORDER BY
cumulative DESC
;


--Discount Impact Analysis
--Discount Efficiency (AOV Uplift Analysis)
SELECT 
Discount_Applied,
COUNT(*) total_transactions,
ROUND(AVG(Purchase_Amount),2) aov,
ROUND(SUM(Purchase_Amount),2) revenue
FROM
`customer.walmart`
GROUP BY 
1;

--Customer Acquisition Cost vs. Revenue
SELECT 
Discount_Applied,
ROUND(AVG(Purchase_Amount),2) First_Purchase_Value
FROM 
`customer.walmart`
WHERE 
Repeat_Customer = FALSE 
GROUP BY 
1;

--Profitability Proxy (Simulasi Margin)
SELECT 
Product_Name,
ROUND(SUM(Purchase_Amount),2) Revenue,
ROUND(SUM(CASE 
WHEN Discount_Applied = FALSE THEN Purchase_Amount * 0.30 
WHEN Discount_Applied = TRUE THEN Purchase_Amount * 0.10
END),2)Estimated_Profit
FROM
`customer.walmart`
GROUP BY 
1
ORDER BY 
Estimated_Profit DESC;


--REGIONAL SALES
-- city most revenue
SELECT
City,
ROUND(SUM(Purchase_Amount),2) total_revenue
FROM
`customer.walmart`
GROUP BY
1
ORDER BY
2 DESC
;

-- best-selling category
SELECT
City,
Category,
ROUND(AVG(Purchase_Amount),2) aov
FROM
`customer.walmart`
GROUP BY
1,2
ORDER BY
3 DESC
;

--AOV comparison per city
SELECT
City,
ROUND(AVG(Purchase_Amount),2) aov
FROM
`customer.walmart`
GROUP BY
1
;

--cte koperhensif
WITH CityRevenue AS (
    SELECT
        City,
        SUM(Purchase_Amount) AS Total_Revenue,
        COUNT(Customer_ID) AS Total_Transactions,
        SUM(Purchase_Amount) / COUNT(Customer_ID) AS Average_Order_Value
    FROM
        `customer.walmart`
    GROUP BY
        City
),
CityProductRank AS (
    SELECT
        City,
        Category,
        SUM(Purchase_Amount) AS Category_Revenue,
        RANK() OVER (
            PARTITION BY City 
            ORDER BY SUM(Purchase_Amount) DESC
        ) AS Category_Rank
    FROM
        `customer.walmart`
    GROUP BY
        City, Category
)
SELECT
    CR.City,
    CR.Total_Revenue,
    CR.Total_Transactions,
    CR.Average_Order_Value,
    (SELECT CPR.Category FROM CityProductRank CPR 
     WHERE CPR.City = CR.City AND CPR.Category_Rank = 1) AS Top_Selling_Category,
        CASE
        WHEN CR.Total_Revenue > (SELECT AVG(Total_Revenue) * 1.5 FROM CityRevenue)
             AND CR.Average_Order_Value > 500
        THEN 'A-Priority (Potensi Cabang Baru/Gudang Utama)'
        
        WHEN CR.Total_Revenue > (SELECT AVG(Total_Revenue) FROM CityRevenue)
             AND CR.Total_Transactions > 1000 -- Ambil angka asumsi transaksi tinggi
        THEN 'B-Priority (Maksimalkan Stok Lokal/Gudang Mikro)'
        
        ELSE 'C-Priority (Perlu Riset/Minimalisir Stok)'
    END AS Strategic_Recommendation
FROM
    CityRevenue CR
ORDER BY
    CR.Total_Revenue DESC;

--Regional Benchmarking (Perbandingan Relatif)
WITH City_Stats AS (
    SELECT 
        City, 
        AVG(Purchase_Amount) as AOV
    FROM `customer.walmart`
    GROUP BY 1
),
National_Stats AS (
    SELECT AVG(Purchase_Amount) as National_AOV FROM `customer.walmart`
)
SELECT 
    c.City,
    c.AOV,
    n.National_AOV,
    CASE 
      WHEN c.AOV > n.National_AOV THEN 'Above Average (Premium)'
      ELSE 'Below Average (Mass Market)'
    END Performance_Status
FROM City_Stats c, National_Stats n
ORDER BY
c.AOV DESC;

--Payment Preference Mapping (Analisis Operasional)
SELECT 
City,
ROUND(COUNT(CASE WHEN Payment_Method = 'Credit Card' THEN 1 END) * 100.0 / COUNT(*),2) CC_Usage_Pct,
ROUND(COUNT(CASE WHEN Payment_Method = 'Cash on Delivery' THEN 1 END) * 100.0 / COUNT(*),2) COD_Usage_Pct,
ROUND(COUNT(CASE WHEN Payment_Method = 'Debit Card' THEN 1 END) * 100.0 / COUNT(*),2) DC_Usage_Pct,
ROUND(COUNT(CASE WHEN Payment_Method = 'UPI' THEN 1 END) * 100.0 / COUNT(*),2) UPI_Usage_Pct
FROM
`customer.walmart`
GROUP BY 
1;

--Demand Volatility Analysis (Stabilitas Permintaan)
SELECT 
City,
ROUND(AVG(Purchase_Amount),2) Avg_Sales,
ROUND(STDDEV(Purchase_Amount),2) as Sales_Volatility
FROM
`customer.walmart`
GROUP BY
1
ORDER BY
Sales_Volatility DESC;

--Localized Product Affinity (Kecocokan Budaya/Lokal)
WITH City_Product_Rank AS (
SELECT 
City,
Product_Name,
ROUND(SUM(Purchase_Amount), 2) Revenue,
RANK() OVER (PARTITION BY City ORDER BY SUM(Purchase_Amount) DESC) crank
FROM
`customer.walmart`
GROUP BY 1, 2
)
SELECT * FROM City_Product_Rank
WHERE crank <= 3; 

--CUSTOMER LOYALTI AND RETENTION
-- identify why customer return
SELECT 
  Product_Name,
  Category,
  COUNT(*) as Total_Transactions,
  COUNT(CASE WHEN Repeat_Customer = TRUE THEN 1 END) as Repeat_Transactions,
  ROUND(COUNT(CASE WHEN Repeat_Customer = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) as Repeat_Rate_Pct,
  ROUND(AVG(Rating), 2) as Avg_Rating
FROM 
  `customer.walmart`
GROUP BY 
  Product_Name,
  Category
ORDER BY 
  Repeat_Rate_Pct DESC;

-- program loyalty customer
SELECT 
  Gender,
  CASE 
    WHEN Age < 25 THEN 'Gen Z'
    WHEN Age BETWEEN 25 AND 40 THEN 'Millennial'
    ELSE 'Gen X/Boomer'
  END as Age_Group,
  Payment_Method,
  COUNT(*) as Total_Loyal_Customers,
  AVG(Purchase_Amount) as Avg_Spend_Per_Transaction
FROM 
  `customer.walmart`
WHERE 
    Repeat_Customer = TRUE
GROUP BY 
    1, 2, 3
ORDER BY 
    Total_Loyal_Customers DESC
LIMIT 5;

--Improve customer satisfaction based on ratings
SELECT 
  Repeat_Customer,
  COUNT(*) as Total_Customers,
  ROUND(AVG(Rating), 2) as Avg_Rating,
  ROUND(AVG(Purchase_Amount), 2) as Avg_Spending,  
  COUNT(CASE WHEN Discount_Applied = TRUE THEN 1 END) * 100.0 / COUNT(*) as Discount_Usage_Pct
FROM 
  `customer.walmart`
GROUP BY 
  Repeat_Customer;


-- BOOSTING ANALYSIS
--Monetary/Revenue Prediction Clustering
-- Tujuan: Mengelompokkan profil demografi berdasarkan nilai belanja rata-rata (AOV)
-- dan total kontribusi pendapatan untuk menemukan segmen 'High Value'.
SELECT
    -- Dimensi Profiling (Siapa mereka?)
    CASE 
        WHEN Age < 25 THEN 'Gen Z (<25)'
        WHEN Age BETWEEN 25 AND 40 THEN 'Millennial (25-40)'
        ELSE 'Gen X/Boomer (>40)'
    END AS Age_Group,
    Gender,
    City,

    -- Metrik Prediksi Pendapatan
    COUNT(*) AS Total_Transactions,               -- Seberapa besar pasarnya?
    ROUND(AVG(Purchase_Amount), 2) AS Avg_Spend,  -- Prediksi nilai belanja per orang
    ROUND(SUM(Purchase_Amount), 2) AS Total_Revenue, -- Total kontribusi uang

    -- Label Segmen (Sederhana)
    CASE 
        WHEN AVG(Purchase_Amount) > (SELECT AVG(Purchase_Amount) FROM `customer.walmart`) * 1.2 THEN 'High Value'
        WHEN AVG(Purchase_Amount) < (SELECT AVG(Purchase_Amount) FROM `customer.walmart`) * 0.8 THEN 'Low Value'
        ELSE 'Average Value'
    END AS Value_Segment

FROM
    `customer.walmart`
GROUP BY
    1, 2, 3 -- Group by Age_Group, Gender, City
HAVING
    COUNT(*) > 5 -- Filter agar data statistik valid (minimal 5 orang per grup)
ORDER BY
    Avg_Spend DESC;

--Rating vs. Potential Churn Proxy
-- Tujuan: Mengidentifikasi kategori produk yang memiliki tingkat kegagalan (Rating rendah) tertinggi.
-- Rating 1-2 dianggap sebagai proxy untuk 'Churn' (Pelanggan kecewa).

SELECT
    Category,
    
    -- Metrik Kualitas
    ROUND(AVG(Rating), 1) AS Average_Rating,
    
    -- Volume Transaksi
    COUNT(*) AS Total_Sales,
    
    -- Menghitung Jumlah Pelanggan Kecewa (Rating 1 atau 2)
    SUM(CASE WHEN Rating <= 2 THEN 1 ELSE 0 END) AS High_Risk_Churn_Count,
    
    -- Menghitung Persentase Kegagalan (Failure Rate)
    ROUND(
        (SUM(CASE WHEN Rating <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 
    2) AS Churn_Risk_Percentage

FROM
    `customer.walmart`
GROUP BY
    Category
ORDER BY
    Churn_Risk_Percentage DESC; -- Urutkan dari yang paling berisiko


-- market basket analysis
-- Tujuan: Menghitung Confidence dan Support untuk pasangan kategori produk.
-- Asumsi: Satu Customer_ID dianggap sebagai satu keranjang belanja.

WITH Pairs AS (
    -- Langkah 1: Buat kombinasi pasangan kategori dalam satu Customer_ID (Self-Join)
    SELECT 
        T1.Category AS Product_A, -- Produk Pemicu (Antecedent)
        T2.Category AS Product_B, -- Produk Ikutan (Consequent)
        T1.Customer_ID
    FROM 
        `customer.walmart` T1
    JOIN 
        `customer.walmart` T2 ON T1.Customer_ID = T2.Customer_ID
    WHERE 
        T1.Category != T2.Category -- Hindari pasangan (Baju, Baju)
),
Stats AS (
    -- Langkah 2: Hitung frekuensi kejadian
    SELECT 
        Product_A,
        Product_B,
        COUNT(*) AS Frequency_Together, -- Berapa kali A & B muncul bareng
        (SELECT COUNT(*) FROM `customer.walmart`) AS Total_Transactions
    FROM 
        Pairs
    GROUP BY 
        Product_A, Product_B
),
Product_A_Stats AS (
    -- Langkah 3: Hitung frekuensi Produk A sendirian (untuk penyebut Confidence)
    SELECT 
        Category, 
        COUNT(*) AS Frequency_A
    FROM 
        `customer.walmart`
    GROUP BY 
        Category
)
-- Langkah 4: Hitung Metrik MBA Akhir
SELECT 
    S.Product_A AS Jika_Membeli_Ini,
    S.Product_B AS Maka_Akan_Membeli_Ini,
    
    -- Support: Seberapa populer kombinasi ini di seluruh toko?
    ROUND((S.Frequency_Together * 100.0 / S.Total_Transactions), 2) AS Support_Pct,
    
    -- Confidence: Seberapa yakin B dibeli jika A sudah dibeli? (Paling Penting)
    -- Rumus: (Frekuensi A & B) / (Frekuensi A)
    ROUND((S.Frequency_Together * 100.0 / PA.Frequency_A), 2) AS Confidence_Pct

FROM 
    Stats S
JOIN 
    Product_A_Stats PA ON S.Product_A = PA.Category
ORDER BY 
    Confidence_Pct DESC
LIMIT 10;

-- Discount Uplift vs. Rating Drop
-- Tujuan: Membandingkan kinerja Penjualan (AOV) vs Kualitas (Rating) 
-- antara transaksi normal dan transaksi diskon.

SELECT
    Discount_Applied,
    
    -- 1. Analisis Uplift (Dampak ke Penjualan)
    COUNT(*) AS Total_Transactions,
    ROUND(AVG(Purchase_Amount), 2) AS Avg_Order_Value,
    ROUND(SUM(Purchase_Amount), 2) AS Total_Revenue,
    
    -- 2. Analisis Rating Drop (Dampak ke Kepuasan)
    ROUND(AVG(Rating), 2) AS Avg_Rating,
    
    -- Persentase Pelanggan Tidak Puas (Rating <= 3)
    ROUND(
        SUM(CASE WHEN Rating <= 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
    1) AS Dissatisfaction_Rate_Pct

FROM
    `customer.walmart`
GROUP BY
    Discount_Applied;
