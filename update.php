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

if(isset($_GET['data']) && $db && isset($_GET['test'])){
	try{
		$data = @json_decode(@urldecode($_GET['data']));
		$pluginVersion = $data['pluginVersion'];
		$lightroomVersion = $data['lightroomVersion'];
		$hash = $data['hash'];
		$arch = $data['arch'];
		$os = $data['os'];
		if array_key_exists('username', $data){
		    $username = $data['username'];
        } else {
            $username = "Nil";
        }
        if array_key_exists('userSymbol', $data){
            $userSymbol = $data['userSymbol'];
        } else {
            $userSymbol = "?";
        }
        if array_key_exists('uploadCount', $data){
            $uploadCount = $data['uploadCount'];
        } else {
            $uploadCount = 0;
        }
		$sql = $db->prepare("INSERT INTO `lrplugin`.`users` (`hash`, `arch`, `lightroomVersion`, `pluginVersion`,  `os`, `uploadCount`, `userSymbol`, `username`) VALUES (:hash, :arch, :lightroomVersion, :pluginVersion, :os, :uploadCount, :userSymbol, :username)");
		
        $sql = $db->prepare("SELECT id from users WHERE hash = ?");
		$sql->execute(array($hash));
		
        if ($result = $sql->fetch()) {
			print_r($result);

		}


		} catch (Exception e) {
			//do nothing, we don't care too much about the db
		}
}
//http://code.kyl191.net/update.php?plugin=net.kyl191.lightroom.export.stash&data=%7B%22arch%22%3A%22x64%22%2C%22hash%22%3A%22b2a9de933867c3a013f079f6fade8473%22%2C%22lightroomVersion%22%3A%7B%22build%22%3A829322%2C%22major%22%3A4%2C%22minor%22%3A1%2C%22publicBeta%22%3Afalse%2C%22revision%22%3A0%7D%2C%22os%22%3A%22Windows+7+Business+Edition%22%2C%22pluginVersion%22%3A%7B%22major%22%3A20120705%2C%22minor%22%3A2345%2C%22revision%22%3A25587836%7D%2C%22uploadCount%22%3A48%2C%22userSymbol%22%3A%22%7E%22%2C%22username%22%3A%22kyl191%22%7D&test
?>
