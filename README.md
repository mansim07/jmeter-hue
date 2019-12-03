# jmeter_hue
Custom Jmeter Setup for Hue

-----Right now only Impala works, the query is set in Jmeter User Defined Variables in SLOW_IMPALA_QUERY*-------------------------------
- This will run jmeter against Hue with customizations
- It will check to make sure you have Java8 installed if not, it installs it in the jmeter_hue directory(Not sure if this works on OSX).  You may have to make sure you have Java8 on OSX.
- It will create an iplist.csv file with all local IPs.  Useful if you have a server with several IPs to create a multiple client emulation.
- Requires a valid users.csv file for your cluster and this must be in the jmeter_hue directory in format "username,password".  See "jmeter_hue/jmeter.sh -h" for flags to specify.  Defaults to "jmeter_hue/users.csv"
- Requires a valid jmx Jmeter script to run.  See default "jmeter_hue/HueHiveImpala514.jmx" as best example.  Also see "jmeter_hue/*.jmx".  JMeter script must be in jmeter_hue directory.  See help for flags to specify
- See "jmeter_hue/jmeter.sh -h" for flags to specify hue host, port and other options.
- You can use convert_firefox_har.py to generate URLs, headers and post data from Firefox HAR file to help create other Jmeter files.
- You can use curl_test.sh to test GET and POST calls that don't see to be working.
  - ./jmeter_test.sh --server cconner514-1.gce.cloudera.com --port 8888 --user cconner --password Password1 --url "/jobbrowser/api/jobs" --method POST --contenttype "application/x-www-form-urlencoded" --postdata 'filters=[{"text":"user:${user}"},{"time":{"time_value":7,"time_unit":"days"}},{"states":["running"]},{"pagination":{"page":1,"offset":1,"limit":1}}]&interface="schedules"'
- Example start command:

./jmeter.sh --host cconner514-1.gce.cloudera.com --port 8888 --scriptfile HueHiveImpala514.jmx --usersfile users_short.csv


- jmeter.sh -h:

usage: ./jmeter.sh [options]

Jmeter Wrapper for Hue:

OPTIONS
   -n|--disablegui         Disable gui to run on remote systems or in a script
   -t|--scriptfile	   JMX script file to run
   -p|--userprop	   Custom user properties file
   -z|--proxyhost	   Custom HTTP proxy host
   -y|--proxyport	   Custom HTTP proxy port
   -x|--threads		   Number of concurrent threads
   -s|--ssl		   Enable SSL
   -H|--host		   Hue Host
   -P|--port		   Hue Port
   -u|--usersfile	   List of users username,password
   -v|--verbose            Enable verbose logging
   -h|--help               Show this message.



