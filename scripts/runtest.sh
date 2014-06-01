#!/bin/bash

# Pass the script a tag to identify this testrun (e.g. memcache module version being tested)
TAG=$1

DATE=`date +%d-%m-%y--%H:%M:%S-$TAG`
BASEDIR="/root/jmeter"
WEBROOT="/var/www/html"
OUTPUT="$BASEDIR/output"
DEST="$WEBROOT/$DATE"
SECONDS=300
IPADDR=$(/sbin/ifconfig eth0 | /bin/grep 'inet addr' | /bin/cut -d':' -f 2 | /bin/cut -d' ' -f 1)

/sbin/service mysqld restart
/sbin/service httpd restart
/sbin/service memcached restart

/usr/local/jmeter/bin/jmeter -n -t ${BASEDIR}/loadtest.jmx -j $BASEDIR/jmeter.log
mv "$BASEDIR/jmeter.log" $OUTPUT
mv $OUTPUT $DEST
rm -f "$WEBROOT/latest"
ln -s $DEST "$WEBROOT/latest"
# Add .htaccess to override Drupal's default of disabling indexes.
echo "Options +Indexes" > $WEBROOT/latest/.htaccess
echo 'stats' | nc localhost 11211 > "$WEBROOT/latest/memcached.stats.txt"

SUMMARY="$WEBROOT/latest/summary.txt"

grep "STAT total_connections" "$WEBROOT/latest/memcached.stats.txt" > $SUMMARY 2>&1
grep "STAT cmd_get" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT cmd_set" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT get_hits" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT get_misses" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT delete_hits" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT delete_misses" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT incr_hits" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT bytes_read" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT bytes_written" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT evictions" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1
grep "STAT total_items" "$WEBROOT/latest/memcached.stats.txt" >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

GETS=`grep "STAT cmd_get" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
HITS=`grep "STAT get_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
MISSES=`grep "STAT get_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
RATE=`echo "scale=4;$HITS / $GETS * 100" | bc` >> $SUMMARY 2>&1
echo "Hit rate: $RATE%" >> $SUMMARY 2>&1
RATE=`echo "scale=4;$MISSES / $GETS * 100" | bc` >> $SUMMARY 2>&1
echo "Miss rate: $RATE%" >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

C20x=`grep "rc=\"20" "$WEBROOT/latest/all_queries.jtl" | wc -l` >> $SUMMARY 2>&1
C200=`grep "rc=\"200" "$WEBROOT/latest/all_queries.jtl" | wc -l` >> $SUMMARY 2>&1
C30x=`grep "rc=\"30" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
C302=`grep "rc=\"302" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
C40x=`grep "rc=\"40" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
C50x=`grep "rc=\"50" "$WEBROOT/latest/all_queries.jtl"| wc -l` >> $SUMMARY 2>&1
TOTAL=`expr $C20x + $C30x + $C40x + $C50x` >> $SUMMARY 2>&1
RATE=`echo "scale=2;$TOTAL / $SECONDS" | bc` >> $SUMMARY 2>&1

echo "HTTP return codes:  20x($C20x) 30x($C30x) 40x($C40x)  50x($C50x)" >> $SUMMARY 2>&1
echo " 200: $C200" >> $SUMMARY 2>&1
echo " 302: $C302" >> $SUMMARY 2>&1
echo >> $SUMMARY 2>&1

echo "Pages per second: $RATE" >> $SUMMARY 2>&1
echo >> $SUMMARY 2>&1

cat $SUMMARY

echo "Complete results can be found in $WEBROOT/latest."
echo "Or at http://$IPADDR/$DATE"
echo "Summary at http://$IPADDR/$DATE/summary.txt"