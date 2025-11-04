-- Identificar todas las órdenes PICKED con CompletedQuantity = 0 pero Quantity > 0
SELECT 
    t.DocDate,
    t.DocID, 
    t.ID AS TransID,
    ti.ID AS TransItemID,
    t.Status,
    i.ID ItemID,
    i.SKU,
    i.Name,
    ti.Quantity,
    ti.CompletedQuantity,
    (ti.Quantity - ti.CompletedQuantity) AS Difference
FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
WHERE 
    t.DocType = 'SO'
    AND t.Void = 0
    AND t.Status = 3  -- ORDER_STATUS_PICKED
    AND ti.CompletedQuantity = 0  -- CompletedQuantity incorrecto
    AND ti.Quantity > 0  -- Con cantidad ordenada
ORDER BY t.DocDate DESC;