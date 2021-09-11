<?php
$ip = $_SERVER['REMOTE_ADDR'];
$arp = "/usr/sbin/arp";
$mac = shell_exec("$arp -an " . $ip);
preg_match('/..:..:..:..:..:../',$mac , $matches);
$mac =  @$matches[0];
if ($mac === NULL) {
	echo "Access Denied";
}
?>

<form method="post" action="process.php"> 
	<input type="hidden" name="mac" value="<?php echo $mac; ?>" /> 
	<input type="hidden" name="ip" value="<?php echo $ip; ?>" /> 
	<input type="submit" value="OK" style="padding:10px 20px;" /> 
</form>
