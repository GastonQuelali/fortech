DECLARE @ToDate AS DATETIME = '2025-11-05'
DECLARE @LocationID AS UNIQUEIDENTIFIER = '0020cdc6-16bd-49d2-d16c-08d5e69262b3'
DECLARE @ItemID AS UNIQUEIDENTIFIER = 'b61ae934-4aed-4da5-8383-ac6e92c3755a'; --12296

SELECT
    t.DocDate, 
    t.DocID,
    t.Status,
    ti.ItemID, 
    ti.Quantity * tu.Factor / iu.Factor AS Quantity,
    ti.CompletedQuantity * tu.Factor / iu.Factor AS CompletedQuantity,
    (ti.Quantity * tu.Factor / iu.Factor) - (ti.CompletedQuantity * tu.Factor / iu.Factor) AS Difference,
    CASE 
        WHEN ti.Quantity * tu.Factor / iu.Factor = ti.CompletedQuantity * tu.Factor / iu.Factor THEN 'IGUAL'
        ELSE '<---- DIFERENTE'
    END AS ComparisonStatus
FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
    INNER JOIN IC_UOM_Plans_UOM tu ON tu.UOMPlanID = i.UOMPlanID AND tu.UOMID = ti.UOMID
    INNER JOIN IC_UOM_Plans_UOM iu ON iu.UOMPlanID = i.UOMPlanID AND iu.UOMID = i.SalesUOMID
WHERE 
    t.DocType = 'SO'
    AND t.Void = 0
    AND t.AuthorizationStatus = 1 
    AND t.Status IN (0, 1, 3) 
    AND t.DocDate <= @ToDate
    AND t.LocationID = @LocationID
    AND ti.ItemID = @ItemID
    AND ti.Quantity * tu.Factor / iu.Factor != ti.CompletedQuantity * tu.Factor / iu.Factor -- solo los diferentes
ORDER BY
    ABS((ti.Quantity * tu.Factor / iu.Factor) - (ti.CompletedQuantity * tu.Factor / iu.Factor)) DESC,
    t.DocDate DESC,
    t.ID;