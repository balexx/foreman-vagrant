$TTL 10800
@ IN SOA infra.example.com. root.example.com. (
	1	;Serial
	86400	;Refresh
	3600	;Retry
	604800	;Expire
	3600	;Negative caching TTL
)

@ IN NS infra.example.com.

$ORIGIN example.com.

foreman     IN A  172.16.16.100
infra       IN A  172.16.16.101
fproxy      CNAME infra
