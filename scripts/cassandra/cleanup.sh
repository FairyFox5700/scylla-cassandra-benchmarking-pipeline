#!/bin/bash
CLUSTER_SIZE=3
CLUSTER_NAME="cassandra"

PUBLIC_DNS_NAMES=($(aws ec2 describe-instances --filters "Name=tag:Name,Values=*$CLUSTER_NAME*" --query "Reservations[].Instances[].PublicDnsName" --output text))

for ((i=0; i<CLUSTER_SIZE; i++)); do 

echo "Running nodetool cleanup on instance $i";
ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]} 'nodetool cleanup';
echo "Running nodetool clearsnapshot on instance $i";
ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]} 'nodetool clearsnapshot --all';
ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]} "sudo systemctl stop cassandra;"
ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]} "sudo rm -rf /var/lib/cassandra/data/*;"
done

for ((i=0; i<$CLUSTER_SIZE; i++)); do
  echo "Restarting cassandra on instance $i"
  ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]}  "sudo systemctl start cassandra;"
done

sleep 120
for ((i=0; i<$CLUSTER_SIZE; i++)); do
  echo "Configuring host on instance $i"
  ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]}  "sudo systemctl status cassandra;"
done

CQL="DROP KEYSPACE IF EXISTS ycsb; CREATE KEYSPACE IF NOT EXISTS ycsb WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': '${CLUSTER_SIZE}'} AND DURABLE_WRITES = true; USE ycsb; DROP TABLE IF EXISTS usertable; CREATE TABLE usertable (
    y_id varchar primary key,
    field0 varchar,
    field1 varchar,
    field2 varchar,
    field3 varchar,
    field4 varchar,
    field5 varchar,
    field6 varchar,
    field7 varchar,
    field8 varchar,
    field9 varchar);"

for ((i=0; i<CLUSTER_SIZE; i++)); do 
echo "Dropping and re-creating keyspace and table for YCSB Timeseries Workload..."
ssh -i scalla-key.pem ubuntu@${PUBLIC_DNS_NAMES[$i]} "cqlsh -e \"$CQL\" "
done