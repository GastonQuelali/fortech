-- Verificar el registro específico que encontramos
SELECT 
    t.ID AS TransID,
    ti.ID AS TransItemID,
    t.DocDate,
    t.DocID,
    t.Status,
    i.SKU,
    ti.Quantity,
    ti.CompletedQuantity
FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
WHERE 
    t.ID = '1DD9B06F-7A8B-4791-E653-08DE1754919F'
    AND ti.ItemID = '85336BB2-82A4-4140-9ABA-08DC1CDDF523';