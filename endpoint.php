<html>
<head>
<title>OAuth2 Endpoint</title>
</head>
<body>
<?php
if (isset($_GET['code'])) {
echo "Your code is: " . $_GET['code'];
} elseif (isset($_GET['error'])) {
echo "Oops. Your request had an error: <br />
".$_GET['error']." <br />
".$_GET['error_description'];
} else {
echo "You sure you used this page as an OAuth2 endpoint correctly?";
}
?>
</body>
</html>