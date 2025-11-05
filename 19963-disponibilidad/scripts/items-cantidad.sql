-- LISTA DE PRODUCTOS CON INCONSISTENCIAS Y SU DIFERENCIA TOTAL
DECLARE @ToDate AS DATETIME = '2025-11-05'
DECLARE @LocationID AS UNIQUEIDENTIFIER = '0020cdc6-16bd-49d2-d16c-08d5e69262b3'

SELECT
    i.SKU,
    i.Name,
    SUM(ti.Quantity * tu.Factor / iu.Factor) AS Total_Quantity_ReportUOM,
    SUM(ti.CompletedQuantity * tu.Factor / iu.Factor) AS Total_Completed_ReportUOM,
    SUM((ti.Quantity * tu.Factor / iu.Factor) - (ti.CompletedQuantity * tu.Factor / iu.Factor)) AS Total_Difference_ReportUOM,
    COUNT(*) AS Cantidad_Inconsistencias,
    
    -- Tipos de inconsistencias encontradas
    CASE 
        WHEN COUNT(CASE WHEN t.Status = 3 AND ti.CompletedQuantity = 0 THEN 1 END) > 0 
             AND COUNT(CASE WHEN t.Status = 0 AND ti.CompletedQuantity > 0 THEN 1 END) > 0 
        THEN 'MÚLTIPLES INCONSISTENCIAS'
        WHEN COUNT(CASE WHEN t.Status = 3 AND ti.CompletedQuantity = 0 THEN 1 END) > 0 
        THEN 'PICKED con Completed=0'
        WHEN COUNT(CASE WHEN t.Status = 0 AND ti.CompletedQuantity > 0 THEN 1 END) > 0 
        THEN 'OPEN con Completed>0'
        ELSE 'OTRA INCONSISTENCIA'
    END AS Tipo_Inconsistencia_Principal,

    -- Detalle de conteos por tipo
    COUNT(CASE WHEN t.Status = 3 AND ti.CompletedQuantity = 0 THEN 1 END) AS Count_PICKED_Completed0,
    COUNT(CASE WHEN t.Status = 0 AND ti.CompletedQuantity > 0 THEN 1 END) AS Count_OPEN_CompletedMayor0

FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
    INNER JOIN IC_UOM_Plans_UOM tu ON tu.UOMPlanID = i.UOMPlanID AND tu.UOMID = ti.UOMID
    INNER JOIN IC_UOM_Plans_UOM iu ON iu.UOMPlanID = i.UOMPlanID AND iu.UOMID = i.ReportUOMID

WHERE 
    t.DocType = 'SO'
    AND t.Void = 0
    AND t.AuthorizationStatus = 1
    AND t.Status IN (0, 1, 3) 
    AND t.DocDate <= @ToDate
    AND t.LocationID = @LocationID
    AND ti.Quantity > 0
    AND (
        (t.Status = 3 AND ti.CompletedQuantity = 0) OR
        (t.Status = 0 AND ti.CompletedQuantity > 0)
    )
    AND INACTIVE = 0

GROUP BY
    i.SKU, 
    i.Name

HAVING 
    SUM((ti.Quantity * tu.Factor / iu.Factor) - (ti.CompletedQuantity * tu.Factor / iu.Factor)) != 0

ORDER BY
    i.SKU,
    ABS(SUM((ti.Quantity * tu.Factor / iu.Factor) - (ti.CompletedQuantity * tu.Factor / iu.Factor))) DESC,
    Cantidad_Inconsistencias DESC;