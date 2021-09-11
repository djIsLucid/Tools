<?php 
if( isset( $POST['ip'] ) && isset ( $_POST['mac'] ) ) { 
	$ip = $_POST['ip']; 
	$mac = $_POST['mac']; 
	exec("sudo iptables -I internet 1 -t mangle -m mac --mac-source $mac -j RETURN"); 
	exec("sudo rmtrack " . $ip); 
	sleep(1); 
	echo "User logged in."; 
	exit; 
} else { 
	echo "Access has been denied yo"; 
	exit; 
} 
?>
