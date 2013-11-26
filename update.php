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
		}
	} else {
			//header('Content-type: application/json');
			echo json_encode(array("Invalid plugin"));
	}
} else {
	print_r($_GET);
}

if(isset($_GET['data']) && $db ){
	try{
		$data = @json_decode(@urldecode($_GET['data']), true);

		// Because we're using hash as an index, check that it's exactly 32 characters long.
		$hash = $data['hash'];
		assert_options(ASSERT_BAIL, true);
		assert(strlen($hash) == 32);

		$pluginVersion = $data['pluginVersion']['major'] . "." . $data['pluginVersion']['minor'] . "." . $data['pluginVersion']['revision'];
		$lightroomVersion = $data['lightroomVersion']['major'] . "." . $data['lightroomVersion']['minor'] . "." . $data['lightroomVersion']['build'] . "." . $data['lightroomVersion']['revision'];
		$arch = $data['arch'];
		$os = $data['os'];

		// If the user doesn't want to submit personal data, put placeholders in.
		if (array_key_exists('username', $data)){
			$username = $data['username'];
		} else {
			$username = "Nil";
		}
		if (array_key_exists('uploadCount', $data)){
			$uploadCount = $data['uploadCount'];
		} else {
			$uploadCount = 0;
		}

		$vars = array(':hash' => $hash, ':arch' => $arch, ':os' => $os, ':lightroomVersion' => $lightroomVersion, ':pluginVersion' => $pluginVersion, ':uploadCount' => $uploadCount, ':userSymbol' => $userSymbol, ':username' => $username);

        $sql = $db->prepare("SELECT id from users WHERE hash = :hash");
		$sql->execute(array(':hash' => $hash));
        if ($sql->rowCount() > 0) {
			$sql = $db->prepare("UPDATE `lrplugin`.`users` SET arch = :arch, lightroomVersion = :lightroomVersion, pluginVersion = :pluginVersion,  os = :os, uploadCount = :uploadCount, userSymbol = :userSymbol, username = :username WHERE hash = :hash");
		} else {
			$sql = $db->prepare("INSERT INTO `lrplugin`.`users` (`hash`, `arch`, `lightroomVersion`, `pluginVersion`,  `os`, `uploadCount`, `userSymbol`, `username`) VALUES (:hash, :arch, :lightroomVersion, :pluginVersion, :os, :uploadCount, :userSymbol, :username)");
		}
		$sql->execute($vars);
		$sql->closeCursor();

	} catch (Exception $e) {
		//do nothing, we don't care too much about the db
	}
}
?>
