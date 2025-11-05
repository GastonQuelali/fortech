DECLARE @Doc AS NVARCHAR(200) = 'Reporte disponibilidad de inventario'
DECLARE @ToDate AS DATETIME = '2025-10-27'
DECLARE @LocationID AS UNIQUEIDENTIFIER = '0020cdc6-16bd-49d2-d16c-08d5e69262b3'
DECLARE @ItemID AS UNIQUEIDENTIFIER = 'b61ae934-4aed-4da5-8383-ac6e92c3755a'; --12296

;WITH s AS (
    SELECT	
        s.ItemID,
        SUM(s.Stock / iu.Factor) AS Stock
    FROM ivwStockByDay s WITH (NOEXPAND)
        INNER JOIN IC_Items i WITH (NOLOCK) ON s.ItemID = i.ID
        INNER JOIN IC_UOM_Plans_UOM iu WITH (NOLOCK) ON i.UOMPlanID = iu.UOMPlanID AND iu.UOMID = i.ReportUOMID
        INNER JOIN SA_Locations l WITH (NOLOCK) ON s.LocationID = l.ID
    WHERE 
        s.DocDate <= @ToDate
        AND s.LocationID IN (@LocationID)
        AND s.ItemID = @ItemID
    GROUP BY s.ItemID
),
dis AS (
    SELECT 
        ti.ItemID, ti.SourceTransactionID, 
        SUM(
            CASE WHEN t.DocType = 'PRO_BUI' THEN ti.Quantity * -1 ELSE ti.Quantity END
            * tu.Factor / iu.Factor
        ) AS DispatchedQuantity			
    FROM SA_Trans_Items ti
        INNER JOIN IC_Items i ON ti.ItemID = i.ID
        INNER JOIN SA_Transactions t ON ti.TransID = t.ID
        INNER JOIN SA_Document_Types tdocs ON t.DocType = tdocs.ID 
        INNER JOIN IC_UOM_Plans_UOM tu ON i.UOMPlanID = tu.UOMPlanID AND tu.UOMID = ti.UOMID
        INNER JOIN IC_UOM_Plans_UOM iu ON i.UOMPlanID = iu.UOMPlanID AND iu.UOMID = i.ReportUOMID 
    WHERE 
        t.Void = 0 
        AND tdocs.Inventory_Action <> 0 
        AND t.ImpactStock = 1
        AND (
            (t.DocType = 'PRO_BUI' AND ti.RowType = 1)
            OR (t.DocType != 'PRO_BUI')
        )
        AND t.DocDate <= @ToDate
    GROUP BY ti.ItemID, ti.SourceTransactionID
), o AS (
    SELECT 
        t.ID, ti.ItemID, 
        SUM(ti.Quantity * tu.Factor / iu.Factor) AS OrderedQuantity
    FROM SA_Trans_Items ti
        INNER JOIN IC_Items i ON ti.ItemID = i.ID
        INNER JOIN SA_Transactions t ON ti.TransID = t.ID
        INNER JOIN SA_Document_Types tdocs ON t.DocType = tdocs.ID 
        INNER JOIN IC_UOM_Plans_UOM tu ON i.UOMPlanID = tu.UOMPlanID AND tu.UOMID = ti.UOMID
        INNER JOIN IC_UOM_Plans_UOM iu ON i.UOMPlanID = iu.UOMPlanID AND iu.UOMID = i.ReportUOMID 
    WHERE 
        t.Void = 0 
        AND t.DocType IN ('SO', 'MAN_ORD') 
        AND (
            (t.AuthorizationStatus = 1 AND t.DocType = 'SO' AND t.Status IN (0, 1, 3))
            OR (t.DocType = 'MAN_ORD' AND t.Status != 1 AND ti.RowType = 1)
        )
        AND t.LocationID = @LocationID
        AND t.DocDate <= @ToDate
    GROUP BY t.ID, ti.ItemID
)
SELECT
    0 AS StockAllocationType,
    i.ItemClassID, ic.Name AS ItemClassName,
    i.BrandID, b.Name AS BrandName,
    i.ID, i.SKU, i.Name, i.ReportUOMID AS UOMID, 
    u.Name AS UOMName, 
    ISNULL(s.Stock, 0) AS Stock, 
    ISNULL(so.OrderedQuantity, 0) AS Ordered, 
    ISNULL(so.DispatchedQuantity, 0) AS Dispatched
FROM IC_Items i
    INNER JOIN IC_UOM u WITH (NOLOCK) ON i.ReportUOMID = u.ID
    LEFT JOIN IC_ItemClasses ic WITH (NOLOCK) ON i.ItemClassID = ic.ID
    LEFT JOIN IC_Brands b WITH (NOLOCK) ON i.BrandID = b.ID
    LEFT JOIN s ON s.ItemID = i.ID
    LEFT JOIN SA_Files f WITH (NOLOCK) ON i.WebStoreImage = f.ID 
    LEFT JOIN (
        SELECT 
            o.ItemID, 
            ISNULL(SUM(o.OrderedQuantity), 0) AS OrderedQuantity, 
            ISNULL(SUM(dis.DispatchedQuantity), 0) AS DispatchedQuantity
        FROM o
            LEFT JOIN dis ON o.ID = dis.SourceTransactionID AND o.ItemID = dis.ItemID
            INNER JOIN SA_Transactions t ON o.ID = t.ID
        GROUP BY o.ItemID
    ) so ON so.ItemID = i.ID
WHERE 
    i.ItemType = 'I' 
    AND i.NonInventoryItem = 0
    AND i.ID = @ItemID
    AND ISNULL(s.Stock, 0) <> 0
ORDER BY ic.Name, i.SKU, i.Name;



