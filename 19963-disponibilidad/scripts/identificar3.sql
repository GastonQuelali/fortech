SELECT 
    t.DocDate,
    t.DocID, 
    t.ID,
    t.Status,
    CASE t.Status
        WHEN 0 THEN 'ORDER_STATUS_OPEN'
        WHEN 1 THEN 'ORDER_STATUS_PARTIAL' 
        WHEN 2 THEN 'ORDER_STATUS_CLOSED'
        WHEN 3 THEN 'ORDER_STATUS_PICKED'
        WHEN 4 THEN 'ORDER_STATUS_BACKORDER'
        WHEN 5 THEN 'ORDER_STATUS_MANUALLY_BILLED'
    END AS StatusName,
    i.SKU,
    ti.Quantity,
    ti.CompletedQuantity,
    (ti.Quantity - ti.CompletedQuantity) AS Difference
FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
WHERE 
    t.DocType = 'SO'
    AND t.Void = 0
    AND t.Status = 3  -- Solo órdenes PICKED
    AND ti.CompletedQuantity = 0  -- Pero con CompletedQuantity = 0
    AND ti.Quantity > 0  -- Y que tengan cantidad ordenada
ORDER BY t.DocDate DESC;