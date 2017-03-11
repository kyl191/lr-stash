<?php
require 'vendor/autoload.php';

date_default_timezone_set('UTC');

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;

function md5Files($dirpath){
	$files=array();
	// Open the directory
	if (is_dir($dirpath)){
		$dir=opendir($dirpath);
		// Read directory into image array
		while (($file = readdir($dir))!==false) {
			if ((strcasecmp(substr($file,-5),".json") != 0) && (strcasecmp(substr($file, -1), ".") != 0)) {
				$files[$file] = md5_file($dirpath . $file);
			}
		}
		closedir($dir);
	} else {
		echo "Oops. Can't find the directory ".$dirpath.". Might want to check it.<br />";
	}
	// don't sort the array, let the script will handle the sorting
	reset($files);
	return $files;
}

// Make sure that the plugin is named correctly
if (isset($_GET['plugin']) && (strncasecmp($_GET['plugin'], "net.kyl191.lightroom", 20) == 0)) {
	$dir = $_SERVER['DOCUMENT_ROOT'] . "/" . $_GET['plugin'] . "/head/";
	if(file_exists($dir) && is_dir($dir)) {
		$filelist = $dir . "md5sums.json";
		if(file_exists($filelist)){
			//header('Content-type: application/json');
			echo file_get_contents($filelist);
		} else {
			$md5 = json_encode(md5Files($dir));
			@file_put_contents($filelist,$md5,LOCK_EX);
			//header('Content-type: application/json');
			echo $md5;
			flush();
		}
	} else {
			//header('Content-type: application/json');
			echo json_encode(array("Invalid plugin"));
	}
} else {
	print_r($_GET);
}

if(isset($_GET['data'])){
	try{
		$data = @json_decode(@urldecode($_GET['data']), true);
		$dynamodb = new DynamoDbClient([
      'region'   => 'us-west-2',
      'version'  => 'latest',
    ]);
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
