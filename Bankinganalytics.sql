/* =====================================================
BANKING ANALYTICS PROJECT
Author: Yash Mishra
Tools Used: MySQL, Power BI

Project Objective:
Developed an end-to-end Banking Analytics solution to
analyze customer demographics, loan portfolio
performance, branch performance, credit risk and
data quality issues.
===================================================== */

/* =====================================================
SECTION 1 : DATABASE & TABLE CREATION
===================================================== */
CREATE DATABASE BankingAnalytics;
USE BankingAnalytics;
CREATE TABLE Customers (
     Customer_ID INT,
     First_Name VARCHAR(50),
     Last_Name VARCHAR(50),
     Gender VARCHAR(20),
     Age INT,
     City VARCHAR(100),
     Annual_Income DECIMAL(15,2),
     Branch_ID INT
 ); 
 
CREATE TABLE Branches (
    Branch_ID INT,
    Branch_Name VARCHAR(50),
    City VARCHAR(50),
    Region VARCHAR(20)
);
CREATE TABLE Accounts (
    Account_ID INT,
    Customer_ID INT,
    Account_Type VARCHAR(30),
    Balance DECIMAL(15,2)
);
CREATE TABLE Loans (
    Loan_ID INT,
    Customer_ID INT,
    Loan_Type VARCHAR(50),
    Loan_Amount DECIMAL(15,2),
    Loan_Status VARCHAR(20)
);
CREATE TABLE CreditScores (
    Customer_ID INT,
    Credit_Score INT
);
CREATE TABLE Transactions (
    Transaction_ID INT,
    Account_ID INT,
    Transaction_Type VARCHAR(20),
    Amount DECIMAL(15,2)
);
/* =====================================================
SECTION 2 : DATA QUALITY AUDIT
===================================================== */
-- Missing Income Check

SELECT COUNT(*) AS Missing_Income
FROM Customers
WHERE Annual_Income = 0;

-- Duplicate Customer Check

SELECT Customer_ID,
COUNT(*) AS Duplicate_Count
FROM Customers
GROUP BY Customer_ID
HAVING COUNT(*) > 1;

-- Negative Balance Check

SELECT COUNT(*) AS Negative_Balances
FROM Accounts
WHERE Balance < 0;

-- Suspicious Transactions

SELECT COUNT(*) AS Suspicious_Transactions
FROM Transactions
WHERE Amount >= 950000;

-- Invalid Age Audit

SELECT
    CASE
        WHEN Age < 0 OR Age > 120 THEN 'Invalid'
        WHEN Age < 18 THEN 'Minor'
        WHEN Age BETWEEN 18 AND 60 THEN 'Adult'
        ELSE 'Senior Citizen'
    END AS Age_Category,
    COUNT(*) AS Customer_Count
FROM Customers
GROUP BY Age_Category;

/* =====================================================
SECTION 3 : DATA CLEANING
===================================================== */

-- Clean Tables

CREATE TABLE Customers_Clean AS
SELECT DISTINCT *
FROM Customers;

CREATE TABLE Accounts_Clean AS
SELECT DISTINCT *
FROM Accounts;

CREATE TABLE Loans_Clean AS
SELECT DISTINCT *
FROM Loans;

CREATE TABLE Transactions_Clean AS
SELECT DISTINCT *
FROM Transactions;

CREATE TABLE CreditScores_Clean AS
SELECT DISTINCT *
FROM CreditScores;

/* =====================================================
SECTION 4 : DATA VALIDATION
===================================================== */

SELECT COUNT(*) Total,
COUNT(DISTINCT Customer_ID) Unique_Count
FROM Customers_Clean;

SELECT COUNT(*) Total,
COUNT(DISTINCT Account_ID) Unique_Count
FROM Accounts_Clean;

SELECT COUNT(*) Total,
COUNT(DISTINCT Loan_ID) Unique_Count
FROM Loans_Clean;

SELECT COUNT(*) Total,
COUNT(DISTINCT Transaction_ID) Unique_Count
FROM Transactions_Clean;

SELECT COUNT(*) Total,
COUNT(DISTINCT Customer_ID) Unique_Count
FROM CreditScores_Clean;

/* =====================================================
SECTION 5 : BUSINESS ANALYSIS
===================================================== */

-- Loan Distribution

SELECT
Loan_Type,
COUNT(*) AS Total_Loans
FROM Loans
GROUP BY Loan_Type
ORDER BY Total_Loans DESC;

-- Loan Status Analysis

SELECT
Loan_Status,
COUNT(*) AS Total_Count
FROM Loans
GROUP BY Loan_Status;

-- Top Performing Branches

SELECT
b.Branch_Name,
COUNT(c.Customer_ID) AS Customer_Count
FROM Branches b
LEFT JOIN Customers c
ON b.Branch_ID = c.Branch_ID
GROUP BY b.Branch_Name
ORDER BY Customer_Count DESC
LIMIT 10;

-- Average Income by Gender

SELECT
Gender,
ROUND(AVG(Annual_Income),2) AS Avg_Income
FROM Customers
WHERE Annual_Income > 0
GROUP BY Gender;

-- Average Income by Branch

SELECT
b.Branch_Name,
ROUND(AVG(c.Annual_Income),2) AS Avg_Income
FROM Branches b
JOIN Customers c
ON b.Branch_ID = c.Branch_ID
WHERE c.Annual_Income > 0
GROUP BY b.Branch_Name
ORDER BY Avg_Income DESC
LIMIT 10;

-- High Risk Customers

SELECT
c.Customer_ID,
c.First_Name,
c.Last_Name,
cs.Credit_Score
FROM Customers c
JOIN CreditScores cs
ON c.Customer_ID = cs.Customer_ID
WHERE cs.Credit_Score < 600
ORDER BY cs.Credit_Score;

-- Top 10 Largest Loan Holders

SELECT
    c.Customer_ID,
    c.First_Name,
    l.Loan_Type,
    l.Loan_Amount
FROM Customers c
JOIN Loans l
    ON c.Customer_ID = l.Customer_ID
ORDER BY l.Loan_Amount DESC
LIMIT 10;

-- Top 5 Highest Income Customers 

WITH RankedCustomers AS (
    SELECT
        Customer_ID,
        First_Name,
        Annual_Income,
        ROW_NUMBER() OVER (ORDER BY Annual_Income DESC) AS rn
    FROM Customers
    WHERE Annual_Income > 0
)
SELECT Customer_ID, First_Name, Annual_Income
FROM RankedCustomers
WHERE rn <= 5;

-- Branch Performance Ranking

SELECT
b.Branch_Name,
COUNT(c.Customer_ID) AS Customer_Count,
RANK() OVER(
ORDER BY COUNT(c.Customer_ID) DESC
) AS Branch_Rank
FROM Branches b
JOIN Customers c
ON b.Branch_ID = c.Branch_ID
GROUP BY b.Branch_Name;

-- Branch-Level Risk Profile 

WITH BranchRiskProfile AS (
    SELECT
        b.Branch_Name,
        b.Region,
        COUNT(DISTINCT c.Customer_ID) AS Total_Customers,
        ROUND(AVG(cs.Credit_Score), 1) AS Avg_Credit_Score,
        COUNT(CASE WHEN cs.Credit_Score < 600 THEN 1 END) AS High_Risk_Customers,
        ROUND(SUM(l.Loan_Amount), 2) AS Total_Loan_Exposure
    FROM Branches b
    JOIN Customers_Clean c ON b.Branch_ID = c.Branch_ID
    JOIN CreditScores_Clean cs ON c.Customer_ID = cs.Customer_ID
    JOIN Loans_Clean l ON c.Customer_ID = l.Customer_ID
    GROUP BY b.Branch_Name, b.Region
)
SELECT *,
    ROUND(High_Risk_Customers * 100.0 / Total_Customers, 1) AS High_Risk_Pct
FROM BranchRiskProfile
ORDER BY High_Risk_Pct DESC;

-- Risk Category & Loan Exposure

SELECT
    CASE
        WHEN cs.Credit_Score < 600 THEN 'High Risk'
        WHEN cs.Credit_Score BETWEEN 600 AND 750 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS Risk_Category,
    COUNT(*) AS Customers,
    ROUND(
        SUM(l.Loan_Amount),
        2
    ) AS Total_Loan_Exposure
FROM Loans l
JOIN CreditScores cs
    ON l.Customer_ID = cs.Customer_ID
GROUP BY Risk_Category;

-- Dashboard-Ready View: Customer Risk Summary

CREATE VIEW vw_Customer_Risk_Summary AS
SELECT
    c.Customer_ID,
    c.First_Name,
    c.Last_Name,
    c.City,
    c.Annual_Income,
    cs.Credit_Score,
    CASE
        WHEN cs.Credit_Score < 600 THEN 'High Risk'
        WHEN cs.Credit_Score BETWEEN 600 AND 750 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS Risk_Category,
    l.Loan_Type,
    l.Loan_Amount,
    l.Loan_Status
FROM Customers_Clean c
JOIN CreditScores_Clean cs ON c.Customer_ID = cs.Customer_ID
JOIN Loans_Clean l ON c.Customer_ID = l.Customer_ID;

