# header
This Perl script is a comprehensive tool for performing HTTP header injection testing on a specified URL.

# Install
```
git clone https://github.com/DKSALL9/header.git
```

# Usage
```
Option headers requires an argument
Usage:
  perl header.pl --url https://target.com/resource
  perl header.pl --url https://target.com/resource --pfile payloads.txt --timeout 15 --verbose --threads 4 --headers "X-Custom:Value,X-Test:123"

Options:
  --url <url>         Target URL
  --pfile <file>      Payload File
  --timeout <secs>    HTTP Timeout (default: 10 seconds)
  --verbose           Enable verbose logging
  --threads <num>     Number of concurrent threads (default: 1)
  --headers <list>    Custom headers (comma-separated, e.g., "Key:Value,AnotherKey:Value")
  --user-agent <str>  Custom User-Agent string
```
