-- CASOS ESPECIALES.       STOCK ORDERED DISPTACHED
-- FORMULA --> STOCK - ( ORDERED - DISPATCHED )

DECLARE @ToDate AS DATETIME = '2025-11-05'
DECLARE @LocationID AS UNIQUEIDENTIFIER = '0020cdc6-16bd-49d2-d16c-08d5e69262b3'

SELECT
    -- t.DocDate, 
    t.DocID, 
    -- t.ID AS TransID,
    t.Status,
    -- CASE t.Status
    --     WHEN 0 THEN 'ORDER_STATUS_OPEN'
    --     WHEN 1 THEN 'ORDER_STATUS_PARTIAL' 
    --     WHEN 3 THEN 'ORDER_STATUS_PICKED'
    -- END AS StatusName,
    i.SKU,
    i.Name,
    ti.Quantity * tu.Factor / iu.Factor AS Quantity_ReportUOM,
    ti.CompletedQuantity * tu.Factor / iu.Factor AS Completed_ReportUOM,
    (ti.Quantity * tu.Factor / iu.Factor) - (ti.CompletedQuantity * tu.Factor / iu.Factor) AS Difference_ReportUOM,
    
    -- Solo marcar como inconsistencia los casos REALES
    CASE 
        WHEN t.Status = 3 AND ti.CompletedQuantity = 0 THEN 'INCONSISTENCIA: PICKED con Completed=0'
        WHEN t.Status = 0 AND ti.CompletedQuantity > 0 THEN 'INCONSISTENCIA: OPEN con Completed>0'
        ELSE 'Diferencia esperada'
    END AS InconsistencyType

FROM SA_Trans_Items ti
    INNER JOIN SA_Transactions t ON ti.TransID = t.ID
    INNER JOIN IC_Items i ON ti.ItemID = i.ID
    INNER JOIN IC_UOM_Plans_UOM tu ON tu.UOMPlanID = i.UOMPlanID AND tu.UOMID = ti.UOMID
    INNER JOIN IC_UOM_Plans_UOM iu ON iu.UOMPlanID = i.UOMPlanID AND iu.UOMID = i.ReportUOMID

WHERE 
    t.DocType = 'SO'
    AND t.Void = 0
    AND t.AuthorizationStatus = 1  -- SOLO órdenes AUTORIZADAS
    AND t.Status IN (0, 1, 3) 
    AND t.DocDate <= @ToDate
    AND t.LocationID = @LocationID
    AND ti.Quantity > 0  -- FILTRAR: Excluir registros donde Quantity es 0
    AND (
        -- SOLO estas son inconsistencias REALES:
        (t.Status = 3 AND ti.CompletedQuantity = 0) OR  -- PICKED pero Completed=0
        (t.Status = 0 AND ti.CompletedQuantity > 0)     -- OPEN pero Completed>0
        -- Status 1 (PARTIAL) con diferencias es NORMAL, no es inconsistencia
    )
ORDER BY
    i.SKU,
    CASE WHEN t.Status = 3 AND ti.CompletedQuantity = 0 THEN 0 ELSE 1 END,  -- Críticos primero
    t.DocDate DESC;