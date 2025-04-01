import click
import requests

SESSION_TOKEN = None  # Global variable to store the session token

@click.group()
def cli():
    """CBRAIN CLI: Your command-line gateway to CBRAIN."""
    pass

@click.command()
@click.option("--username", prompt="Your CBRAIN username", help="Your CBRAIN username.")
@click.option("--password", prompt="Your CBRAIN password", hide_input=True, help="Your CBRAIN password.")
def login(username, password):
    """
    Log in to CBRAIN and grab a session token.

    This command sends a POST request to the CBRAIN login endpoint
    and attempts to extract the session token from the server's response.
    """
    global SESSION_TOKEN  # Access the global session token variable

    try:
        # Start a new requests session to manage cookies
        session = requests.Session()

        # Prepare the login data (username and password)
        login_data = {
            "login": username,
            "password": password,
        }

        # Set the content type header for form data
        login_headers = {
            "Content-Type": "application/x-www-form-urlencoded",
        }

        # Send the POST request to the CBRAIN login endpoint
        login_response = session.post(
            "https://portal.cbrain.mcgill.ca/session",
            data=login_data,
            headers=login_headers,
            allow_redirects=False,  # Prevent automatic redirects
        )
        login_response.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)

        # Check the server's response status code
        if login_response.status_code == 401:
            # Login failed due to incorrect credentials
            click.echo("❌ Login failed. Authentication failed. Double-check your credentials.")
        elif login_response.status_code == 403:
            # Login may have been blocked by the server (rate limiting or other reasons)
            click.echo("⚠️ Login may have been blocked by the server. Please verify manually.")
            click.echo(login_response.headers)  # Print the headers for debugging
        elif f"Logged in as {username}" in login_response.text:
            # Login appears successful based on the presence of the username in the HTML
            if "BrainPortal5_Session" in login_response.cookies:
                # Extract the session token from the cookie
                SESSION_TOKEN = login_response.cookies["BrainPortal5_Session"]
                click.echo("🎉 Login successful! You're in.")
                click.echo(f"Your session token: {SESSION_TOKEN}")
            else:
                # Login successful, but no session cookie found
                click.echo("⚠️ Login appears successful, but no session cookie found. Please verify manually.")
        elif login_response.cookies:
            # Login might be successful (cookie present), but needs manual verification
            click.echo("⚠️ Login may have been successful. Please verify manually.")
            click.echo(login_response.cookies)
        else:
            # Login failed for an unknown reason
            click.echo("❌ Login failed. Authentication failed. Double-check your credentials.")

    except requests.exceptions.RequestException as e:
        # Handle network errors or other request exceptions
        click.echo(f"Login failed. Something went wrong: {e}")

cli.add_command(login)

if __name__ == "__main__":
    cli()