const express = require('express');
const bodyParser = require('body-parser');
const fetch = require('node-fetch');
const path = require('path');
const dns = require('dns');
const ipInfo = require('node-ipinfo');
const asInfo = require('ip-to-asn');
const ipCidr = require('ip-cidr');

const app = express();
const token = 'e923235a764c48';		// IPinfo.io API token
const ipinfo = new ipInfo(token);
const asinfo = new asInfo();

app.use(bodyParser.json());

/* Gets basic IP information */
app.get('/', (req, res) => {
	fetch('https://ifconfig.me/ip')
		.then(resp => resp.text())
		.then(data => {
			ipinfo.lookupIp(data).then(resp => res.send(resp));
		});
})

/* logs a visitor's Geo, IP, and HTTP Header information */
app.get('/log', (req, res) => {
	const ipInfo = req.ipInfo;
	const headers = req.headers;

	const userInfo = {
		"timestamp": new Date().toUTCString(),
		"data": {
			"ip": ipInfo["ip"].split(":")[3],
			"range": ipInfo["range"],
			"country": ipInfo["country"],
			"region": ipInfo["region"],
			"timezone": ipInfo["timezone"],
			"city": ipInfo["city"],
			"ll": ipInfo["ll"],
			"headers": req.headers,
		},
	}

	fs.appendFile(getLog, JSON.stringify(userInfo, null, 4), (err) => {
		if (err) {
			console.error(err);
		} else {
			console.log("successfully logged a new visitor");
			res.send("")
		}
	})
})
 	
/* 
	Gets the full IP block from a range 
*/
app.get('/ip-range/:host', (req, res) => {
	const { host } = req.params;

	dns.lookup(host, (err, ipAddr) => {
		return asinfo.query([ipAddr], (err, data) => {
			const asnData = Object.values(data)[0];
			const ipBlock = new ipCidr(asnData.range).toArray().map(ip => ip);

			res.json(ipBlock);
		})	
	})
})

/* 
	Gets general Geo and Organization info from a given IP address 
*/
app.get('/ipv4/:host', (req, res) => {
	const { host } = req.params;

	dns.lookup(host, (err, ipAddr) => {
		if (ipAddr === undefined) {
			res.send(`Failed to resolve ${host}`)
			return;
		}

		return ipinfo.lookupIp(ipAddr).then(response => {
			response["_query"] = host
			if (response.hostname === undefined) {
				res.send(response);
				return;
			} else {
				const name = response.hostname.split('.')
								.reverse()
								.slice(0,2)
								.reverse()
								.join('.')

				// Resolve nameservers of the target
				dns.resolveNs(name, (err, data) => response["_ns"] = data.map(x => x));

				// Get ASN, IP range, Org string and registrar
				asinfo.query([response.ip], (err, data) => {
					const asnData = Object.values(data)[0];

					response["_range"] = asnData.range;
					response["_asn"] = asnData.ASN;
					response["_organization"] = asnData.description;
					response["_registrar"] = asnData.registrar;

					res.json(response);
				})
			}
		});
	})
})


/* and boom goes the dynamite... */
app.listen(6301, () => console.log("Geo-api running on port 6301!"));
