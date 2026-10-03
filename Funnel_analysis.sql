WITH session_data AS (
  SELECT
    fullVisitorId,
    trafficSource.medium AS traffic_source,
    totals.pageviews AS pageviews,
    totals.transactions AS transactions,
    EXISTS (
      SELECT 1 FROM UNNEST(hits) h
      WHERE h.type = 'PAGE'
        AND h.page.pagePath LIKE '%/google+redesign/%'
    ) AS viewed_product,
    EXISTS (
      SELECT 1 FROM UNNEST(hits) h
      WHERE h.eventInfo.eventAction = 'Add to Cart'
    ) AS added_cart,
    EXISTS (
      SELECT 1 FROM UNNEST(hits) h
      WHERE h.eCommerceAction.action_type = '5'
    ) AS reached_checkout
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
),

traffic_summary AS (
  SELECT
    traffic_source,
    COUNT(DISTINCT fullVisitorId) AS total_visitors,
    COUNTIF(pageviews > 1) AS multi_page_sessions
  FROM session_data
  GROUP BY traffic_source
),

product_viewers AS (
  SELECT traffic_source,
         COUNT(DISTINCT fullVisitorId) AS product_viewers
  FROM session_data
  WHERE viewed_product
  GROUP BY traffic_source
),

cart_adds AS (
  SELECT traffic_source,
         COUNT(DISTINCT fullVisitorId) AS added_to_cart
  FROM session_data
  WHERE added_cart
  GROUP BY traffic_source
),

checkouts AS (
  SELECT traffic_source,
         COUNT(DISTINCT fullVisitorId) AS reached_checkout
  FROM session_data
  WHERE reached_checkout
  GROUP BY traffic_source
),

purchases AS (
  SELECT traffic_source,
         COUNT(DISTINCT fullVisitorId) AS completed_purchase
  FROM session_data
  WHERE transactions >= 1
  GROUP BY traffic_source
)

SELECT
  t.traffic_source,
  t.total_visitors,
  t.multi_page_sessions,
  COALESCE(pv.product_viewers, 0) AS product_viewers,
  COALESCE(c.added_to_cart, 0) AS added_to_cart,
  COALESCE(co.reached_checkout, 0) AS reached_checkout,
  COALESCE(p.completed_purchase, 0) AS completed_purchase,
  SAFE_DIVIDE(COALESCE(p.completed_purchase, 0), t.total_visitors) AS visitor_to_purchase_rate
FROM traffic_summary t
LEFT JOIN product_viewers pv USING (traffic_source)
LEFT JOIN cart_adds c USING (traffic_source)
LEFT JOIN checkouts co USING (traffic_source)
LEFT JOIN purchases p USING (traffic_source)
ORDER BY t.total_visitors DESC;
