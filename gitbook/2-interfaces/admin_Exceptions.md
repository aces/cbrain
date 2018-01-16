Information shown on the Exceptions tab can be useful to view and manage the Exceptions that are raised during the normal usage of CBRAIN. This is particularly useful for the administrator who is also a programmer, to identify and correct problems that occur in CBRAIN.

## Exceptions tab

All of the exceptions which occur in CBRAIN are shown on this tab. The following information is shown for each Exception:
* **Type**: The type of exception.
* **Message**: Part of the **Message** for the exception.
* **Method**: The method that raised the exception (e.g. GET/POST).
* **Controller**: The controller that raised the exception.
* **Action**: The action that raised the exception.
* **Format**: The format of the exception.
* **User**: The user that caused the exception.
* **Revision**: The revision of the code that raised the exception.
* **Raised at**: The time that the exception occurred.

## View information about an exception

If you want more information about a particular exception you can click on it on the Exceptions tab. This can be useful for a programmer to replicate the exception and debug the CBRAIN code.

There are four different sections on the show page of an exception:
* **Request**: In this section the information about the request that raised the exception is shown (e.g. the *URL*, *Method* and *Revision*)
* **Backtrace**: The full backtrace of the exception is shown, which can be helpful for a programmer to find the origin of the exception.
* **Session**: The information about the session that raised the exception (e.g. the *client* or *user agent*).  Sometimes it can be useful in order to reproduce the exception.
* **Headers**: This shows information about the HTTP header fields.

