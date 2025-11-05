DECLARE @Doc AS NVARCHAR(200) = 'Query obtener listado de art�culos en transacciones de ventas'

DECLARE @LocationID AS UNIQUEIDENTIFIER = '0020cdc6-16bd-49d2-d16c-08d5e69262b3'
DECLARE @term AS NVARCHAR(200) = '12296';

DECLARE @ToDate AS DATETIME = '2025-11-05'

;WITH s AS (
SELECT 
    s.ItemID, SUM(s.Stock / iu.Factor) Stock
FROM ivwStock s WITH (NOEXPAND)
    INNER JOIN IC_UOM_Plans_UOM iu ON iu.UOMPlanID = s.UOMPlanID AND iu.UOMID = s.SalesUOMID
WHERE
    1 = 1

AND s.LocationID = @LocationID

GROUP BY 
    s.ItemID
            ),
so AS (
SELECT
	ItemID, SUM(OrderedQuantity) OrderedQuantity, SUM(DispatchedQuantity) DispatchedQuantity
FROM
(
	SELECT
		ti.ItemID, 
		SUM(ti.Quantity * tu.Factor / iu.Factor) OrderedQuantity,
		SUM(ti.CompletedQuantity * tu.Factor / iu.Factor) DispatchedQuantity
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

	GROUP BY ti.ItemID

	UNION ALL

	SELECT
		ti.ItemID, 
		SUM(ti.Quantity * tu.Factor / iu.Factor) OrderedQuantity,
		SUM(CASE WHEN t.DocType = 'PRO_BUI' THEN ti.Quantity*-1 ELSE ti.Quantity END * tu.Factor / iu.Factor) DispatchedQuantity
  		
	FROM SA_Trans_Items ti
		INNER JOIN SA_Transactions t ON ti.TransID = t.ID
		INNER JOIN IC_Items i ON ti.ItemID = i.ID
		INNER JOIN IC_UOM_Plans_UOM tu ON tu.UOMPlanID = i.UOMPlanID AND tu.UOMID = ti.UOMID
		INNER JOIN IC_UOM_Plans_UOM iu ON iu.UOMPlanID = i.UOMPlanID AND iu.UOMID = i.SalesUOMID
	WHERE 
		t.DocType = 'MAN_ORD'
		AND t.Void = 0
		AND t.Status != 1
		AND ti.RowType = 1 
  		AND t.DocDate <= @ToDate
 		AND t.LocationID = @LocationID
	GROUP BY ti.ItemID
) t
GROUP BY ItemID
            ), 
allocated_quantities AS (
SELECT
	ti.ItemID, ti.AttributeOption1ID, ti.AttributeOption2ID,
	SUM(ti.Quantity * tu.Factor / su.Factor) AllocatedQuantity
FROM
	SA_Trans_Items ti
	INNER JOIN SA_Transactions t ON ti.TransID = t.ID
	INNER JOIN IC_Items i ON ti.ItemID = i.ID
	INNER JOIN IC_UOM_Plans_UOM tu ON tu.UOMPlanID = i.UOMPlanID AND tu.UOMID = ti.UOMID
	INNER JOIN IC_UOM_Plans_UOM su ON su.UOMPlanID = i.UOMPlanID AND su.UOMID = i.SalesUOMID
	INNER JOIN SA_Document_Types dt ON t.DocType = dt.ID
WHERE
	t.Void = 0
	AND t.DocType IN('STOCK_ALLO') 
    AND t.ID NOT IN
    (
        SELECT
	        DISTINCT ti.RelatedTransactionID
        FROM SA_Trans_Items ti 
	        INNER JOIN SA_Transactions t ON ti.TransID = t.ID
	        INNER JOIN SA_Transactions inv ON inv.InvoiceID = t.ID AND inv.DocType = 'INVOICE'
	        INNER JOIN SA_Document_Types dt ON t.DocType = dt.ID
        WHERE 
	        t.DocType = 'D_INVOICE'
	        AND inv.Void = 0
    )


GROUP BY
    ti.ItemID, ti.AttributeOption1ID, ti.AttributeOption2ID 
)

SELECT 
    TOP 50 0 StockAllocationType, i.ID Value, i.SKU, i.Name, i.SalesDescription, i.ItemType, i.NonInventoryItem,
    i.SalesUOMID SalesUOM, i.TaxScheduleID, u.Name SalesUOMName, i.WebStoreImage, i.AllowPriceEditing, i.AllowDescriptionEditing,

    ISNULL(s.Stock, 0) Stock,
    ISNULL(so.OrderedQuantity, 0) Ordered, 
    ISNULL(so.DispatchedQuantity, 0) Dispatched,
    ISNULL(alloc.AllocatedQuantity, 0) AllocatedQuantity
FROM IC_Items i WITH (NOLOCK)

    LEFT JOIN IC_ItemModels m WITH (NOLOCK) ON i.ItemModelID = m.ID
    LEFT JOIN SA_Files f WITH (NOLOCK) ON i.WebStoreImage = f.ID
    LEFT JOIN s WITH (NOLOCK) ON s.ItemID = i.ID
    LEFT JOIN so WITH (NOLOCK) ON so.ItemID = i.ID
    LEFT JOIN IC_UOM u WITH (NOLOCK) ON i.SalesUOMID = u.ID
    LEFT JOIN allocated_quantities alloc ON i.ID = alloc.ItemID

WHERE 
    i.SalesItem = 1
AND i.Inactive = 0
AND (
        i.SKU LIKE '%' + @term + '%'
        OR i.Name LIKE '%' + @term + '%' 
        OR i.BarCode LIKE '%' + @term + '%' 
        OR i.ManufacturerReference LIKE '%' + @term + '%' 
        OR i.VendorReference LIKE '%' + @term + '%'
        OR m.Name LIKE '%' + @term + '%'
)
ORDER BY i.SKU, i.Name


