<?php include("db.php")

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

if (isset($_GET['plugin']) && (strncasecmp($_GET['plugin'], "net.kyl191.lightroom", 20) == 0)) {
	$dir = $_SERVER['DOCUMENT_ROOT'] . "/" . $_GET['plugin'] . "/head/";
	$filelist = $dir . "md5sums.json";
	if(file_exists($dir) && is_dir($dir)) {
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

if(isset($_GET['data']) && $db){
	try{
		$data = @json_decode($_GET['data'])
		$pluginVersion = $data['pluginVersion']

		} catch (Exception e) {
			//do nothing, we don't care too much about the db
		}
}

?>
