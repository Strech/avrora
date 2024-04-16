# Development

To test `Avrora` with real Confluent Schema Registry it is recommended to use
official demo project.

## 1. Setup Confluent demo project

```console
$ git clone git clone git@github.com:confluentinc/cp-demo.git
$ cd cp-demo
$ git checkout -b 7.5.1-post origin/7.5.1-post
```

Apply the following patch to minimize the setup and keep the bare-minimum.

> [!NOTE]
> You may see some errors and warnings, but you could ignore them, for example:
>
> Error response from daemon: No such container: connect  
> WARNING: Expected to find at least 6 subjects in Schema Registry but found...

```diff
diff --git a/scripts/start.sh b/scripts/start.sh
index 50b5b41a..535b7a0e 100755
--- a/scripts/start.sh
+++ b/scripts/start.sh
@@ -5,6 +5,8 @@ source ${DIR}/helper/functions.sh
 source ${DIR}/env.sh
 
 #-------------------------------------------------------------------------------
+# Disable visualization by default
+VIZ=false
 
 # Do preflight checks
 preflight_checks || exit
@@ -15,7 +17,7 @@ ${DIR}/stop.sh
 CLEAN=${CLEAN:-false}
 
 # Build Kafka Connect image with connector plugins
-build_connect_image
+# build_connect_image
 
 # Set the CLEAN variable to true if cert doesn't exist
 if ! [[ -f "${DIR}/security/controlCenterAndKsqlDBServer-ca1-signed.crt" ]] || ! check_num_certs; then
@@ -86,75 +88,82 @@ docker-compose exec kafka1 kafka-configs \
 
 
 # Bring up more containers
-docker-compose up --no-recreate -d schemaregistry connect control-center
+# FIXME
+# docker-compose up --no-recreate -d schemaregistry connect control-center
+docker-compose up --no-recreate -d schemaregistry
 
 echo
 echo -e "Create topics in Kafka cluster:"
 docker-compose exec tools bash -c "/tmp/helper/create-topics.sh" || exit 1
 
 # Verify Kafka Connect Worker has started
-MAX_WAIT=240
-echo -e "\nWaiting up to $MAX_WAIT seconds for Connect to start"
-retry $MAX_WAIT host_check_up connect || exit 1
+# FIXME
+# MAX_WAIT=240
+# echo -e "\nWaiting up to $MAX_WAIT seconds for Connect to start"
+# retry $MAX_WAIT host_check_up connect || exit 1
 
 #-------------------------------------------------------------------------------
 
-echo -e "\nStart streaming from the Wikipedia SSE source connector:"
-${DIR}/connectors/submit_wikipedia_sse_config.sh || exit 1
+# FIXME
+# echo -e "\nStart streaming from the Wikipedia SSE source connector:"
+# ${DIR}/connectors/submit_wikipedia_sse_config.sh || exit 1
 
-# Verify connector is running
-MAX_WAIT=120
-echo
-echo "Waiting up to $MAX_WAIT seconds for connector to be in RUNNING state"
-retry $MAX_WAIT check_connector_status_running "wikipedia-sse" || exit 1
+# # Verify connector is running
+# MAX_WAIT=120
+# echo
+# echo "Waiting up to $MAX_WAIT seconds for connector to be in RUNNING state"
+# retry $MAX_WAIT check_connector_status_running "wikipedia-sse" || exit 1
 
-# Verify wikipedia.parsed topic is populated and schema is registered
-MAX_WAIT=120
-echo
-echo -e "Waiting up to $MAX_WAIT seconds for subject wikipedia.parsed-value (for topic wikipedia.parsed) to be registered in Schema Registry"
-retry $MAX_WAIT host_check_schema_registered || exit 1
+# # Verify wikipedia.parsed topic is populated and schema is registered
+# MAX_WAIT=120
+# echo
+# echo -e "Waiting up to $MAX_WAIT seconds for subject wikipedia.parsed-value (for topic wikipedia.parsed) to be registered in Schema Registry"
+# retry $MAX_WAIT host_check_schema_registered || exit 1
 
 #-------------------------------------------------------------------------------
 
-# Verify Confluent Control Center has started
-MAX_WAIT=300
-echo
-echo "Waiting up to $MAX_WAIT seconds for Confluent Control Center to start"
-retry $MAX_WAIT host_check_up control-center || exit 1
+# # Verify Confluent Control Center has started
+# FIXME
+# MAX_WAIT=300
+# echo
+# echo "Waiting up to $MAX_WAIT seconds for Confluent Control Center to start"
+# retry $MAX_WAIT host_check_up control-center || exit 1
 
-echo -e "\nConfluent Control Center modifications:"
-${DIR}/helper/control-center-modifications.sh
-echo
+# echo -e "\nConfluent Control Center modifications:"
+# ${DIR}/helper/control-center-modifications.sh
+# echo
 
 
 #-------------------------------------------------------------------------------
 
-# Start more containers
-docker-compose up --no-recreate -d ksqldb-server ksqldb-cli restproxy
+# FIXME
+# # Start more containers
+# docker-compose up --no-recreate -d ksqldb-server ksqldb-cli restproxy
 
-# Verify ksqlDB server has started
-echo
-echo
-MAX_WAIT=120
-echo -e "\nWaiting up to $MAX_WAIT seconds for ksqlDB server to start"
-retry $MAX_WAIT host_check_up ksqldb-server || exit 1
+# # Verify ksqlDB server has started
+# echo
+# echo
+# MAX_WAIT=120
+# echo -e "\nWaiting up to $MAX_WAIT seconds for ksqlDB server to start"
+# retry $MAX_WAIT host_check_up ksqldb-server || exit 1
 
-echo -e "\nRun ksqlDB queries:"
-${DIR}/ksqlDB/run_ksqlDB.sh
+# echo -e "\nRun ksqlDB queries:"
+# ${DIR}/ksqlDB/run_ksqlDB.sh
 
 if [[ "$VIZ" == "true" ]]; then
   build_viz || exit 1
 fi
 
-echo -e "\nStart additional consumers to read from topics WIKIPEDIANOBOT, WIKIPEDIA_COUNT_GT_1"
-${DIR}/consumers/listen_WIKIPEDIANOBOT.sh
-${DIR}/consumers/listen_WIKIPEDIA_COUNT_GT_1.sh
+# FIXME
+# echo -e "\nStart additional consumers to read from topics WIKIPEDIANOBOT, WIKIPEDIA_COUNT_GT_1"
+# ${DIR}/consumers/listen_WIKIPEDIANOBOT.sh
+# ${DIR}/consumers/listen_WIKIPEDIA_COUNT_GT_1.sh
 
-echo
-echo
-echo "Start the Kafka Streams application wikipedia-activity-monitor"
-docker-compose up --no-recreate -d streams-demo
-echo "..."
+# echo
+# echo
+# echo "Start the Kafka Streams application wikipedia-activity-monitor"
+# docker-compose up --no-recreate -d streams-demo
+# echo "..."
 
 
 #-------------------------------------------------------------------------------
```

Save it with name `cp-demo.patch` and run the following command.

```console
$ git apply cp-demo.patch
```

To ensure HTTP(S) connectivity with the generated certificate,
add the schema registry to your system's hosts file:

```console
$ sudo sh -c 'echo "0.0.0.0 schemaregistry" >> /etc/hosts'
```

## 2. Get certificates

Copy the certificate from the Docker container to your local machine and
convert the PEM certificate to a DER-encoded format.

```console
$ docker cp schemaregistry:/etc/kafka/secrets/snakeoil-ca-1.crt .
$ openssl x509 -in snakeoil-ca-1.crt -outform DER -out snakeoil-ca-1.der
```

## 3. Check Schema Registry connectivity

Test the connection to the Schema Registry using the `Avrora.HTTPClient`
with the converted certificate. Run the following code in your console.

```elixir
# Setup the URL and read the certificate
url = "https://superUser:superUser@schemaregistry:8085/subjects"
cert = File.read!(Path.expand("./snakeoil-ca-1.der"))

# Make a get request to the Schema Registry it should output `{:ok, []}`
# (because no data was populated in patched `start.sh` script)
Avrora.HTTPClient.get(url, [ssl_options: [verify: :verify_peer, cacerts: [cert]]])
```
