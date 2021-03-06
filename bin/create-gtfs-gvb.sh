#!/bin/bash
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATE=$(date +'%Y%m%d')
python manager.py -x -d kv1gvb -c -s http://195.193.209.12/gvbpublicatieinternet/KV1/KV1index.xml
status=$?
rm -rf /tmp/*.txt
if [ $status != 0 ];
then exit 1
fi
psql -d kv1gvb -f ../sql/gtfs-shapes-gvb.sql
psql -d kv1gvb -f ../sql/gtfs-shapes-passtimes.sql
zip -j ../gtfs/gvb/gtfs-kv1gvb-$DATE.zip /tmp/agency.txt /tmp/calendar_dates.txt /tmp/feed_info.txt /tmp/routes.txt /tmp/stops.txt /tmp/stop_times.txt /tmp/trips.txt /tmp/shapes.txt
rm ../gtfs/gvb/gtfs-kv1gvb-latest.zip
ln -s gtfs-kv1gvb-$DATE.zip ../gtfs/gvb/gtfs-kv1gvb-latest.zip

#Validate using Google TransitFeed
python transitfeed/feedvalidator.py ../gtfs/gvb/gtfs-kv1gvb-$DATE.zip -o ../gtfs/gvb/gtfs-kv1gvb-$DATE.html -l 50000 --error_types_ignore_list=ExpirationDate,FutureService
python transitfeed/kmlwriter.py ../gtfs/gvb/gtfs-kv1gvb-$DATE.zip
zip -j ../gtfs/gvb/gtfs-kv1gvb-$DATE.kmz ../gtfs/gvb/gtfs-kv1gvb-$DATE.kml
rm ../gtfs/gvb/gtfs-kv1gvb-$DATE.kml
