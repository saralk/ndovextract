CREATE OR REPLACE FUNCTION 
toseconds(time24 text) RETURNS integer AS $$
SELECT total AS time
FROM
(SELECT
  (cast(split_part($1, ':', 1) as int4) * 3600)      -- hours
+ (cast(split_part($1, ':', 2) as int4) * 60)        -- minutes
+ CASE WHEN $1 similar to '%:%:%' THEN (cast(split_part($1, ':', 3) as int4)) ELSE 0 END -- seconds when applicable
as total
) as xtotal
$$ LANGUAGE SQL;

COPY (
SELECT
'OVapi' as feed_publisher_name,
'http://ovapi.nl/' as feed_publisher_url,
'nl' as feed_lang,
replace(cast(firstday AS text), '-', '') as feed_start_date,
replace(cast(lastday AS text), '-', '') as feed_end_date,
versionnumber as feed_version 
FROM 
delivery
) TO '/tmp/feed_info.txt' WITH CSV HEADER;

create table dataownerurl (company integer primary key, agency_url varchar(50));
insert into dataownerurl values (22, 'http://www.gvb.nl');
insert into dataownerurl values (911, 'http://www.keolis.de');
insert into dataownerurl values (500, 'http://www.arriva.nl');
insert into dataownerurl values (23, 'http://www.htm.nl');
insert into dataownerurl values (600, 'http://www.connexxion.nl');
insert into dataownerurl values (805, 'http://www.connexxion.nl');
insert into dataownerurl values (24, 'http://www.ret.nl');
insert into dataownerurl values (980, 'http://www.sncf.fr');
insert into dataownerurl values (910, 'http://www.db.de');
insert into dataownerurl values (920, 'http://www.nmbs.be');
insert into dataownerurl values (700, 'http://www.veolia.nl');
insert into dataownerurl values (701, 'http://www.veolia.nl');
insert into dataownerurl values (35, 'http://www.ebs-ov.nl');
insert into dataownerurl values (400, 'http://www.syntus.nl');
insert into dataownerurl values (801, 'http://www.syntus.nl');
insert into dataownerurl values (750, 'http://www.qbuzz.nl');
insert into dataownerurl values (100, 'http://www.ns.nl');
insert into dataownerurl values (37, 'http://www.ns.nl');
insert into dataownerurl values (25, 'http://www.gvu.nl');
insert into dataownerurl values (200, 'http://www.ns-hispeed.nl');
insert into dataownerurl values (960, 'http://www.ns-hispeed.nl');
insert into dataownerurl values (300, 'http://www.thalys.nl');
insert into dataownerurl values (501, 'http://www.breng.nl');
insert into dataownerurl values (52, 'http://www.breng.nl');
insert into dataownerurl values (54, 'http://www.valleilijn.nl');

drop table gtfs_stops;
create table gtfs_stops(
stop_id varchar(10) primary key,
stop_code varchar(10),
stop_name varchar(50) not null,
stop_lon double precision not null,
stop_lat double precision not null,
stop_timezone varchar(25),
location_type integer,
parent_station varchar(10),
platform_code varchar(10)
);

copy (
SELECT
NULL AS shape_id,
NULL AS shape_pt_lat,
NULL AS shape_pt_lon,
NULL AS shape_pt_sequence
LIMIT 0
)to '/tmp/shapes.txt' WITH CSV HEADER; 

copy gtfs_stops from '/tmp/stops_positioned.txt' CSV header;

COPY(
SELECT
c.company as agency_id,
name as agency_name,
agency_url,
'Europe/Amsterdam' AS agency_timezone,
'nl' AS agency_lang
FROM
company as c left join dataownerurl as d using (company)
WHERE c.company in (select distinct companynumber from timetable_service)
) TO '/tmp/agency.txt' WITH CSV HEADER;

COPY (
SELECT
'OVapi' as feed_publisher_name,
'http://ovapi.nl/' as feed_publisher_url,
'nl' as feed_lang,
replace(cast(firstday AS text), '-', '') as feed_start_date,
replace(cast(lastday AS text), '-', '') as feed_end_date,
now() as feed_version
FROM delivery
) TO '/tmp/feed_info.txt' WITH CSV HEADER;

COPY (
SELECT
'NS:'||footnote as service_id,
replace(cast(servicedate as text), '-', '') as date,
'1' as exception_type
FROM footnote
) TO '/tmp/calendar_dates.txt' WITH CSV HEADER;

alter table station add column the_geom geometry;
update station set the_geom = ST_Transform(st_setsrid(st_makepoint(x,y), 28992), 4326) WHERE x is not null and y is not null; 
update station set the_geom = st_setsrid(st_makepoint(5.317222,43.455), 4326) where shortname = 'aixtgv';
update station set the_geom = st_setsrid(st_makepoint(8.469858,49.479633), 4326) where shortname = 'mannhe';
update station set the_geom = st_setsrid(st_makepoint(11.627778,52.130556), 4326) where shortname = 'magdeb';

COPY(
SELECT
*
FROM gtfs_stops
UNION
SELECT
shortname as stop_id,
shortname as stop_code,
name as stop_name,
CAST(st_X(the_geom) AS NUMERIC(8,5)) AS stop_lon,
CAST(st_Y(the_geom) AS NUMERIC(9,6)) AS stop_lat,
CASE WHEN (timezone = 1) THEN  'Europe/London' ELSE 'Europe/Amsterdam' END AS stop_timezone,
1      AS location_type,
NULL   AS parent_station,
NULL   AS platform_code
FROM
(SELECT * from station where shortname in (select distinct station from timetable_stop) and trainchanges != 2) as x
where shortname not in (select stop_id from gtfs_stops)
UNION
SELECT DISTINCT
shortname||'|'||COALESCE(departure,'0') as stop_id,
NULL as stop_code,
CASE WHEN (departure is not null) THEN name||' spoor '||departure ELSE name END as stop_name,
COALESCE(CAST(st_X(the_geom) AS NUMERIC(8,5)),0) AS stop_lon,
COALESCE(CAST(st_Y(the_geom) AS NUMERIC(9,6)),0) AS stop_lat,
NULL as stop_timezone,
0      AS location_type,
shortname   AS parent_station,
departure   AS platform_code
FROM
(SELECT * from station as s,timetable_platform as p where p.station = s.shortname and shortname in (select distinct station from timetable_stop) and trainchanges != 2) as x
where shortname||'|'||COALESCE(departure,'0')  not in (select stop_id from gtfs_stops)
UNION
SELECT
shortname||'|0' as stop_id,
NULL as stop_code,
name as stop_name,
COALESCE(CAST(st_X(the_geom) AS NUMERIC(8,5)),0) AS stop_lon,
COALESCE(CAST(st_Y(the_geom) AS NUMERIC(9,6)),0) AS stop_lat,
NULL as stop_timezone,
0      AS location_type,
shortname   AS parent_station,
NULL   AS platform_code
FROM
(SELECT * from station as s WHERE shortname in (select distinct station from timetable_stop) and trainchanges != 2) as x
where shortname||'|0' not in (select stop_id from gtfs_stops)
) TO '/tmp/stops.txt' WITH CSV HEADER;

COPY (
SELECT DISTINCT ON (transmode,companynumber,description)
companynumber||'-'||transmode as route_id,
companynumber as agency_id,
null as route_short_name,
description as route_long_name,
CASE WHEN (transmode in ('NSS','NSB','B','BNS','X','U','Y')) THEN 3 
     WHEN (transmode = 'NSM') THEN 1 
     WHEN (transmode = 'NST') THEN 0
--   WHEN (transmode = 'NSS' or transmode = 'NSB' or transmode = 'B') THEN 714
--   WHEN (transmode in ('ES','HSI','HSN','THA','ICE')) THEN 101
--   WHEN (transmode in ('INT','IC','EC') THEN) 102
--   WHEN (transmode in ('EN','CNL')) THEN 105
--   WHEN (transmode in ('S')) THEN 103
--   WHEN (transmode in ('SPR') THEN 109
     ELSE 2 END as route_type
FROM timetable_transport as t,trnsmode as m,timetable_service as s
WHERE m.code = t.transmode and t.serviceid = s.serviceid
) TO '/tmp/routes.txt' WITH CSV HEADER;

update timetable_service set servicenumber = 0 where servicenumber is null and variant is null;
update timetable_transport set laststop = 999 where serviceid not in (select serviceid from timetable_transport group by serviceid having count(*) > 1);



COPY(
SELECT
companynumber||'-'||transmode as route_id,
'NS:'||footnote as service_id,
service.serviceid||'|'||footnote||'|'||COALESCE(servicenumber,cast (variant as integer)) as trip_id,
name as trip_headsign,
COALESCE(servicenumber,cast (variant as integer))%2 as direction_id,
COALESCE(servicenumber,cast (variant as integer)) as trip_short_name,
service.serviceid as block_id,
CASE WHEN (transmode in ('HSN','HSI')) THEN 1
     WHEN (service.serviceid in (select serviceid from timetable_attribute where code in ('NIIN','GEFI'))) THEN 1
     ELSE 2 END as trip_bikes_allowed
FROM
timetable_service as service,timetable_validity as validity,timetable_transport as trans, station,
(select serviceid,station,row_number() over (partition by serviceid) as service_seq from timetable_stop) as stops
WHERE
validity.serviceid = service.serviceid AND
((validity.laststop = service.laststop AND validity.firststop = service.firststop) or validity.laststop = 999 ) AND
trans.serviceid = service.serviceid AND 
((trans.firststop = service.firststop) or trans.laststop = 999) AND
footnote is not null AND
stops.serviceid = service.serviceid AND
stops.service_seq = service.laststop AND
stops.station = station.shortname
ORDER BY trip_id
) TO '/tmp/trips.txt' WITH CSV HEADER;

copy (
SELECT
trip_id,
CASE WHEN(stop_sequence = 1) THEN departure_time ELSE arrival_time END,
departure_time,
stop_id,
arrival_stop_id,
stop_sequence,
pickup_type,
drop_off_type
FROM 
  (
        SELECT
	service.serviceid||'|'||validity.footnote||'|'||COALESCE(servicenumber,cast (variant as integer)) as trip_id,
	arrivaltime as arrival_time,
	COALESCE(departuretime,arrivaltime) as departure_time,
	stop.station||'|'||COALESCE(departure,'0') as stop_id,
        row_number() over (partition by service.serviceid,validity.footnote,COALESCE(servicenumber,cast (variant as integer)) order by idx asc) as 
stop_sequence,
	CASE WHEN (arrival <> departure) THEN stop.station||'|'||arrival else NULL END as arrival_stop_id,
        CASE
        WHEN (ARRAY['NIIN'] <@ attrs) THEN 1
        WHEN (ARRAY['RESV'] <@ attrs) THEN 2 
        WHEN (ARRAY['IRES'] <@ attrs) THEN 2
        ELSE 0 END as pickup_type,
        CASE
        WHEN (ARRAY['NUIT'] <@ attrs) THEN 1
        WHEN (ARRAY['IRES'] <@ attrs) THEN 2 
        WHEN (ARRAY['RESV'] <@ attrs) THEN 2
        ELSE 0 END as drop_off_type
        FROM
        (SELECT
        stop.serviceid,
        stop.idx,
        cast(array_agg(code) as text[]) as attrs
	FROM
        timetable_stop as stop LEFT JOIN (SELECT serviceid,code,generate_series(cast(firststop as integer),cast(laststop as integer)) as idx FROM 
timetable_attribute) as attr USING (serviceid,idx)
        GROUP BY stop.serviceid,stop.idx
	) as x
        LEFT JOIN (SELECT serviceid,companynumber,servicenumber,variant,generate_series(cast(firststop as integer),cast(laststop as integer)) as idx 
FROM timetable_service) as service USING (serviceid,idx)
        LEFT JOIN timetable_validity as validity USING (serviceid)
        LEFT JOIN timetable_stop as stop USING (serviceid,idx)
        LEFT JOIN timetable_platform as platform USING (serviceid,idx)
   ) as y
ORDER BY trip_id,stop_sequence
) TO '/tmp/stop_times.txt' WITH CSV HEADER;

copy(
SELECT DISTINCT ON (from_stop_id,to_stop_id)
*
FROM (
select distinct on (p1.station,p2.station,shortname,from_stop_id,to_stop_id)
shortname||'|'||p1.arrival as from_stop_id,
shortname||'|'||p2.departure as to_stop_id,
2 as transfer_type,
layovertime as min_transfer_time
from station,
(select distinct on (p.station,p.departure,p.arrival) station,departure,arrival from timetable_platform as p) as p1,
(select distinct on (p.station,p.departure,p.arrival) station,departure,arrival from timetable_platform as p) as p2
WHERE 
p1.station = shortname AND
p2.station = shortname AND
p1.station = p2.station AND
p1.arrival <> p2.departure AND
shortname||'|'||p1.arrival in (select distinct station||'|'||departure from timetable_platform) AND
shortname||'|'||p2.departure in (select distinct station||'|'||departure from timetable_platform)
UNION
(SELECT DISTINCT ON (from_stop_id,to_stop_id)
c.station||'|'||a.departure as from_stop_id,
c.station||'|'||d.departure as to_stop_id,
2 as transfer_type,
(toseconds(dt.departuretime) - toseconds(at.arrivaltime) - 30) as min_transfer_time
FROM
changes as c,
timetable_platform as a,
timetable_platform as d,
timetable_stop as at,
timetable_stop as dt,
station as ats,
station as dts,
timetable_service as from_service,
timetable_service as to_service,
timetable_validity as from_validity,
timetable_validity as to_validity
WHERE
a.serviceid = fromservice AND
d.serviceid = toservice AND
a.station = d.station AND
c.station = a.station AND
a.serviceid = at.serviceid AND
a.idx = at.idx AND
a.station = at.station AND
d.serviceid = dt.serviceid AND
d.idx = dt.idx AND
possiblechange in (1,2) AND
d.station = dt.station AND
ats.shortname = at.station AND
dts.shortname = dt.station AND
from_service.serviceid = fromservice AND
a.idx between from_service.firststop and from_service.laststop AND
to_service.serviceid = toservice AND
d.idx between to_service.firststop and to_service.laststop AND
from_validity.serviceid = fromservice AND
to_validity.serviceid = toservice AND
from_validity.serviceid = fromservice AND
fromservice not in (select serviceid from timetable_attribute where code = 'NIIN') AND
toservice not in (select serviceid from timetable_attribute where code = 'NIIN') AND
--- no idea why this is even possible
fromservice <> toservice AND
a.arrival <> d.departure AND
dt.departuretime > at.departuretime
ORDER BY from_stop_id ASC,to_stop_id ASC,min_transfer_time ASC)
) as transfers
ORDER BY
from_stop_id,to_stop_id,min_transfer_time
) to '/tmp/transfers.txt' WITH CSV HEADER;
