1) Edit `sudo vi /etc/systemd/system/xguard.service`

```
[Unit]
Description=Crossing Guard
Requires=network.target
After=syslog.target network-online.target

[Service]
Type=simple
User=panda
WorkingDirectory=/canvas-supports/crossing-guard
PIDFile=/canvas-supports/crossing-guard/logs/xguard-daemon.pid
ExecStart=/usr/bin/ruby /canvas-supports/crossing-guard/guard.rb
ExecStop=/bin/kill -- $MAINPID
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGTERM
KillMode=process
Environment=SYSTEMD_LOG_LEVEL=debug

# if we crash, restart
RestartSec=30
Restart=always

# This will default to "bundler" if we don't specify it
SyslogIdentifier=xguard

[Install]
WantedBy=multi-user.target
```


2) Reload and Enable

	`sudo systemctl daemon-reload; sudo systemctl enable xguard`

3) Start the service

	`sudo systemctl start xguard`

4) Check the status

	`sudo systemctl status xguard.service`

5) Stop and Restart

	`sudo systemctl stop xguard`

	`sudo systemctl restart xguard`

	`sudo journalctl -u xguard.service`

	`sudo journalctl -u xguard.service --since '1 hour ago'`
	
	`systemctl show xguard.service | grep -i restart`

