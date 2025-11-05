SELECT 
    i.ID AS ItemID,
    i.SKU,
    i.Name,
    COUNT(*) AS InconsistentTransactions,
    SUM(CASE WHEN t.Status = 3 AND ti.CompletedQuantity = 0 THEN 1 ELSE 0 END) AS Status3_ButZeroCompleted,
    SUM(CASE WHEN t.Status IN (0,2) AND ti.CompletedQuantity > 0 THEN 1 ELSE 0 END) AS Status02_ButHasCompleted
FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
WHERE 
    t.DocType = 'SO'
    AND t.Void = 0
    AND t.DocDate <= '2025-10-27'
    AND (
        (t.Status = 3 AND ti.CompletedQuantity = 0)  -- Status 3 pero Completed = 0
        OR (t.Status IN (0,2) AND ti.CompletedQuantity > 0)  -- Status 0/2 pero Completed > 0
    )
    AND t.AuthorizationStatus = 1
GROUP BY i.ID, i.SKU, i.Name
HAVING COUNT(*) > 0
ORDER BY InconsistentTransactions DESC
