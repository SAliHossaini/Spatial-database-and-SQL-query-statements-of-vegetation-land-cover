/*
Name: Ali Hossaini
Final Project
*/


/*
SQL Queries:
*/

-- 1) Write the select or create statement that results in a new table NDVI_statitics that contains the following fields by NDVI_Mean, NDVI_Max,  NDVI_Min, and aggregate of the Total_area.  

DROP TABLE IF EXISTS NDVI_statitics; 
CREATE TABLE NDVI_statitics (NDVI_Mean float, NDVI_Max float, NDVI_Min float, Total_area double precision);
WITH statitics AS
(
SELECT 
Mean (NDVI) AS NDVI_Mean,
Max (NDVI) AS NDVI_Max, 
Min (NDVI) AS NDVI_Min, 
Sum(shape_area) AS Total_area
From NDVI_mask
)
SELECT *
INTO NDVI_statitics
FROM statitics;

-- 2) If you use the count of NDVI pixels as a proxy for area, which year has the most vegetation area per pixel?

WITH years_vegetation_land as
(
SELECT LUSE_date, LUSE_dscrp, sum(Shape_area) as total_vegetation_land
FROM Historical_LUSE
GROUP BY LUSE_date, LUSE_dscrp
), NDVI_raster as
(
SELECT time_period, raster_val, sum(Shape_area) as total_pixels
FROM NDVI_mask 
GROUP BY time_period, raster_val
)
SELECT LUSE_code, LUSE_dscrp, total_vegetation_land / total_pixels as vegetation_land_per_pixel
FROM years_vegetation_land 
INNER JOIN NDVI_raster ON (time_period = LUSE_date)
ORDER BY 3;

-- 3) Write the SQL query that shows the total area of vegetation land in northern half of Ramsey county based on spatial extent of the NDVI mask.

WITH Ramsey_Extent AS
(
SELECT ST_GeomFromWKB(ST_UNION(geom)) AS Ramsey_county, EXT_min_X, EXT_max_X
WHERE CTY_NAME=' Ramsey'
FROM bdry_counties
), half AS (
  SELECT  Northern_half, Ramsey_county
  FROM Ramsey_Extent
  -- This part of the code calculates the midpoint in Ramsey extent.
  CROSS JOIN LATERAL (
  	SELECT ST_xMin(Ramsey) + (ST_xMax(Ramsey) - ST_xMin(Ramsey)) / 2 
  	) 
), 
-- This part of the code takes the geom upper than midpoint as Northern_half.
N_Geom AS (
  SELECT ST_Split(ST_SetSRID(Ramsey, 4269), st_setsrid(half, 4269)) AS Northern_half
  FROM half
)
SELECT Sum(Shape_Area)
 FROM NDVI_mask
INNER JOIN  N_Geom ON Northern_half=ST_Envelope(rast);

-- 4) Write the SQL query that identifies all vegetation land use in 2010 that are within 5 kilometers of Ramsey county centroid.

SELECT name,mn_counties.geom, Historical_LUSE.FID
FROM bdry_counties
INNER JOIN Historical_LUSE
ON ST_DWithin(ST_Centroid(bdry_counties.geom)::geography, Historical_LUSE.geom::geography, 5000)
WHERE CTY_NAME=' Ramsey' and LUSE_date='2010';

-- 5) Write the SQL code that creates a histogram of the vegetation land use in Ramsey county based on NDVI_mask. A histogram is each unique pixel type and total number of pixels.

--Vegetation raster for Ramsey county
WITH Ramsey AS
(
SELECT CTY_NAME,  (ST_Valuecount(ST_Clip(rast,geom))).*
FROM NDVI_mask
INNER JOIN  bdry_counties ON geom=ST_Envelope(rast);
WHERE CTY_NAME=' Ramsey'
)
--pixel count to draw histogram
, histo AS
(
SELECT name, value AS pixel_value, SUM(count) AS total_pixels
FROM Ramsey
GROUP BY name, value
)
--max pixel to draw histogram 
, mx AS
(
SELECT max(total_pixels) as maximum
FROM histo
)
SELECT name, pixel_value, total_pixels, REPEAT('|', CEIL(100 * total_pixels / maximum::numeric)::int) AS histogram
FROM histo,mx
ORDER BY 2;

-- 6) Write the SQL code that reclassifies vegetation land use in Twin-cities so that Parks & Recreation Areas, Vacant/Agricultural, Farmsteads in years before 2000 and Park, Recreational, or Preserve,Golf Course, Agricultural in years after 2000 (LUSE_code= 7,8,10,70,100,173)  would take a unique LUSE_code.

select ST_Reclass(r.rast, 1, '7,8,10,70,100,173:200', '32BSI') as rast
from Historical_LUSE r
inner join bdry_counties s on ST_Intersects(r.rast, s.geom);

-- 7) Which vegetation types (LUSE_code= 7,8,10,70,100,173) decreased from 2010 to 2016 in Ramsey County.

-- Land use 2010 count
WITH landcover_a AS
(
SELECT CTY_NAME,  (ST_Valuecount(ST_Clip(g.rast,s.geom))).*
from Historical_LUSE r
inner join bdry_counties s on ST_Intersects(r.rast, s.geom);
WHERE CTY_NAME='Ramsey' and LUSE_date='2010' and LUSE_code IN (7,8,10,70,100,173)
)
--pixel/landcover 2016 count
, landcover_b AS
(
SELECT CTY_NAME,  (ST_Valuecount(ST_Clip(g.rast,s.geom))).*
from Historical_LUSE r
inner join bdry_counties s on ST_Intersects(r.rast, s.geom);
WHERE CTY_NAME='Ramsey' and LUSE_date='2016' and LUSE_code IN (7,8,10,70,100,173)
)
--sum total count of vegetation land use
, sums AS
(
SELECT a.name as county, a.value AS landcover2010, SUM(a.count) AS total_pixels_a,b.value AS landcover2015, SUM(b.count) AS total_pixels_b
FROM landcover_a a
INNER JOIN landcover_b b ON a.value=b.value
GROUP BY county,a.value,b.value
)
SELECT landcover2010, AS total_pixels_a, landcover2016, total_pixels_b
FROM sums
WHERE total_pixels_a>total_pixels_b;
