1. Get a new session, generate the authenticity_token and the cookie file:

> curl -c /tmp/cb_cookies -X GET --header 'Accept: application/json' 'https://portal.cbrain.mcgill.ca/session/new'

response:

{"authenticity_token":"hkgs7qCiEQZcfsXGMkH4GnTK9Kq26MzUUjYlOPoM8mA="}

2. Create a CBRAIN session:

> curl -X POST -b /tmp/cb_cookies --header 'Content-Type: multipart/form-data' --header 'Accept: application/json' -F login=nbeck -F password=11qq22ww33$ -F authenticity_token=hkgs7qCiEQZcfsXGMkH4GnTK9Kq26MzUUjYlOPoM8mA= 'https://portal.cbrain.mcgill.ca/session'

3. Find all files on data provider

> curl -X GET -b /tmp/cb_cookies --header 'Accept: application/json' 'https://portal.cbrain.mcgill.ca/data_providers/68/browse'



4. Register all the demo_*.mnc.gz file in CBRAIN. These files are on DP but not yest in catalog

5. Extract all ids of newly register files

6. Launch a task on these files

7. Monitoring of tasks status
