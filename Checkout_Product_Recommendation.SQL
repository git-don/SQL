// Purpose: Provide data-driven product reccomendation at checkout
//              -For each product sold over shopify in 2020, surface 1st and 2nd most frequently co-purchased products

WITH PARENT_SKUS AS
(
 // Create list of post-01/01/2020 shopify orders by SKU to serve as parent SKU list
  
 SELECT 
   PROD_SKU AS P_PROD_SKU
  ,ORDER_ID AS P_ORDER_ID
 FROM "DTC_DATA"."WHITEBOX"."JOINEDITEMLEVEL"
 WHERE ORDER_SALESCHANNEL = 'shopify'AND YEAR(ORDER_CREATEDDATE) >= 2020
)
, CHILD_SKUS AS
(
 // Create list of post-01/01/2020 shopify orders by SKU to serve as child SKU list 
  
 SELECT 
    PROD_SKU AS C_PROD_SKU
   ,ORDER_ID AS C_ORDER_ID
 FROM "DTC_DATA"."WHITEBOX"."JOINEDITEMLEVEL"
 WHERE ORDER_SALESCHANNEL = 'shopify'AND YEAR(ORDER_CREATEDDATE) >= 2020
)
, PARENT_CHILD_LIST AS
(
  // For each order, list parent and child SKUs present in order (co-purchased SKUs)
  
  SELECT
     P.P_ORDER_ID
    ,P.P_PROD_SKU
    ,C.C_PROD_SKU
  FROM PARENT_SKUS AS P
  LEFT JOIN CHILD_SKUS AS C
  ON P.P_ORDER_ID = C.C_ORDER_ID
  WHERE C.C_PROD_SKU <> P.P_PROD_SKU
)
,
RANK_PARENT_CHILD_COMBOS as 
(
  // Count all orders for each distinct combination of parent and child SKU,
  // for each parent SKU, rank child SKUs by descending count of orders
  
  SELECT
     P_PROD_SKU
    ,C_PROD_SKU
    ,COUNT(P_ORDER_ID) AS COUNT_OF_ORDERS
    ,RANK() OVER (PARTITION BY P_PROD_SKU ORDER BY COUNT(P_ORDER_ID) DESC) as RANK
  FROM PARENT_CHILD_LIST
  GROUP BY 1,2
  ORDER BY 3 DESC
)
,
FIRST_CHILD AS 
(
  // For each parent SKU, list the most frequently co-purchased child SKU and the number of times that parent and child SKUs were co-purchased
  
  SELECT 
     P_PROD_SKU
    ,C_PROD_SKU
    ,COUNT_OF_ORDERS
  FROM RANK_PARENT_CHILD_COMBOS
  WHERE RANK = 1
)
,
SECOND_CHILD AS 
(
  // For each parent SKU, list the second-most frequently co-purchased child SKU and the number of times that parent and child SKUs were co-purchased
  
  SELECT 
     P_PROD_SKU
    ,C_PROD_SKU
    ,COUNT_OF_ORDERS
  FROM RANK_PARENT_CHILD_COMBOS
  WHERE RANK = 2
)
// Join two previous CTEs to list first and second-most frequently co-purchased child SKUs for each parent SKU and the number of times that each combination of parent and child SKUs were co-purchased

SELECT
   FIRST_CHILD.P_PROD_SKU
  ,FIRST_CHILD.C_PROD_SKU AS FIRST_C_PROD_SKU
  ,FIRST_CHILD.COUNT_OF_ORDERS AS FIRST_COUNT_OF_ORDERS
  ,SECOND_CHILD.C_PROD_SKU AS SECOND_C_PROD_SKU
  ,SECOND_CHILD.COUNT_OF_ORDERS AS SECOND_COUNT_OF_ORDERS
FROM FIRST_CHILD
  LEFT JOIN SECOND_CHILD
  ON FIRST_CHILD.P_PROD_SKU = SECOND_CHILD.P_PROD_SKU
ORDER BY FIRST_COUNT_OF_ORDERS DESC, SECOND_COUNT_OF_ORDERS DESC
;

