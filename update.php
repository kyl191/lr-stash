<?php
require 'vendor/autoload.php';

date_default_timezone_set('UTC');

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;

use Aws\S3\S3Client;

$aws_conf = [
  'region'   => 'us-west-2',
  'version'  => 'latest',
];

$sdk = new Aws\Sdk($aws_conf);

$s3 = $sdk->createS3();
$bucket = "lr-stash";
$key = "head/md5sums.json";
$res = $s3->getObject([
  'Bucket' => $bucket,
  'Key'    => $key,
]);
echo $res['Body']->getContents();

if(isset($_GET['data'])){
	try{
		$data = @json_decode(@urldecode($_GET['data']), true);
		$dynamodb = $sdk->createDynamoDb();
    $marshaler = new Marshaler();

    $item = [];

    $pv = $data['pluginVersion'];
    $item["pluginVersion"] = $pv['major'] . "." . $pv['minor'] . "." . $pv['revision'];

    $lv = $data['lightroomVersion'];
    $item["lightroomVersion"] = $lv['major'] . "." . $lv['minor'] . "." . $lv['build'] . "." . $lv['revision'];

    $item["arch"] = $data['arch'];
    $item["os"] = $data['os'];

    $item["username"] = array_key_exists('username', $data) ?  $data['username'] : "Nil" ;
    $item["uploadCount"] = array_key_exists('uploadCount', $data) ? strval($data['uploadCount']) : '0' ;
    $item["lastSeen"] = gmdate(DateTime::ATOM);

    $item["no_hash"] = !array_key_exists('hash', $data) || empty($data['hash']);
    $item["uuid"] = $item["no_hash"] ? md5($_SERVER['HTTP_X_FORWARDED_FOR']) : $data['hash'];

    $response = $dynamodb->putItem([
        'TableName' => "lr-stash",
        'Item' => $marshaler->marshalItem($item)
    ]);

	} catch (Exception $e) {
		//do nothing, we don't care too much about the db
	}
}
?>
