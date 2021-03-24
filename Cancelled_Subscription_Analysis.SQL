// Purpose: Determine why customers who like the product/barnd are cancelling their subscriptions, bucket analysis by different subscription period lengths
//              - customers who have ordered after their subscription cancellation date presumably liked the brand/product, but did not like being subscribed

WITH CUST_CANCELLED AS 
(
  // Join subscription customer emails onto subscription data–email will be used as a key to join onto order-level data in following CTE

  SELECT 
     C.EMAIL
    ,S.* 
  FROM "FIVETRAN_DATABASE"."RECHARGE"."SUBSCRIPTION" AS S
  INNER JOIN "FIVETRAN_DATABASE"."RECHARGE"."CUSTOMER" AS C
  ON S.CUSTOMER_ID = C.ID
  WHERE S.STATUS = 'CANCELLED'
)
, CUST_ORDER_AFTER_CANCELLATION AS 
(
  // Inner join list of cancelled customers onto order-level data by email, only include customers that have an order after their subscription cancellation date
  
  SELECT 
     C.EMAIL
    ,C.CANCELLATION_REASON
    ,C.CREATED_AT
    ,C.CANCELLED_AT
    ,O.ORDER_ID
    ,O.ORDER_DATE
  FROM CUST_CANCELLED AS C
  INNER JOIN DTC_DATA.WHITEBOX.JOINEDORDERLEVEL AS O
  ON C.EMAIL = O.ORDER_BUYEREMAIL
  WHERE O.ORDER_DATE > C.CANCELLED_AT
)
, CUST_SUB_LENGTH AS 
(
  // Bucket customers who ordered after their cancellation date based subscription length (difference between date subscription was created & date cancelled)
  
  SELECT 
     EMAIL 
    ,CANCELLATION_REASON 
    ,CREATED_AT
    ,CANCELLED_AT
    ,DATEDIFF(D,CREATED_AT,CANCELLED_AT) AS SUBSCRIPTION_LENGTH
    ,CASE WHEN SUBSCRIPTION_LENGTH <= 60 then '1) <= 2 MONTHS'
          WHEN SUBSCRIPTION_LENGTH > 60 and SUBSCRIPTION_LENGTH <= 120 then '2) 2-4 MONTHS'
          WHEN SUBSCRIPTION_LENGTH > 120 and SUBSCRIPTION_LENGTH <= 180 then '3) 4-6 MONTHS'
          WHEN SUBSCRIPTION_LENGTH > 180 then '4) > 6 MONTHS' ELSE NULL END AS SUB_LENGTH_BUCKET
  FROM CUST_ORDER_AFTER_CANCELLATION
  GROUP BY 1,2,3,4
)
, SUB_LENGTH_CUST_COUNT AS 
(
  // Count the number of cancelled subscription customers in each subscription length bucket
  
  SELECT 
     SUB_LENGTH_BUCKET 
    ,COUNT(*) AS SUB_LENGTH_CUST_COUNT
  FROM CUST_SUB_LENGTH 
  GROUP BY 1
)
//Within each subscription length bucket, count customers based on their cancellation reason, determine percentage of customers within subscription length bucket that cancelled for each specific reason

SELECT
   S.SUB_LENGTH_BUCKET
  ,C.CANCELLATION_REASON
  ,COUNT(*) AS CANCELLATION_REASON_CUST_COUNT 
  ,S.SUB_LENGTH_CUST_COUNT
  ,CANCELLATION_REASON_CUST_COUNT/S.SUB_LENGTH_CUST_COUNT AS CANCELLATION_REASON_AS_PERCENTAGE_OF_SUB_LENGTH_CUSTOMERS
FROM CUST_SUB_LENGTH AS C
INNER JOIN SUB_LENGTH_CUST_COUNT AS S
ON C.SUB_LENGTH_BUCKET = S.SUB_LENGTH_BUCKET
GROUP BY 1,2,4
ORDER BY 1 ASC, 5 DESC, 4 DESC, 3 DESC
;

