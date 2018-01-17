This class provides an asynchronous communication mechanism between any CBRAIN user, group or process to any user. A message can be sent by the system to other users or from users to each other.

## How to create a Message

* Go to the "Messages" section.
* Open the "Leave message" panel
* Fill in the form:
  * **To users of project**: Select the recipient of the message.
  * **Critical**: The message will stay on all of the pages until the user decides to hide it.
  * **Send E-mail**: Check the box to send an e-mail message to the user; however, this option is rarely used.
  * **Header**: The header of the text.
  * **Description**: A short description of the message.
  * **Variable text**: To make the variable text look good, make sure that if you provide multiple lines of text (e.g. a list) the first line is different, as it will be the one that gets prepended with the time stamp.
  * **Message type**: Options are `system`, `notice` or `error`:
    * System messages sent by the administrator are displayed in blue.
    * Notices indicating the successful completion of tasks are displayed in green.
    * Error messages referring to errors encountered when executing tasks are displayed in red.
  * **Expiration date**:  An expiration date can also be provided, such that unacknowledged messages disappear from view when they are no longer relevant (for instance, for system broadcast messages).

**Note**: This method will create and update a single Message object
for multiple successive calls that have the same **message type**,
**header**, and **description** arguments, and will concatenate and
timestamp the successive **variable text** messages into it.

## Filters

On the index page of the message you will find a "Filters" panel,
which allows you to define custom rules to find particular 
messages (e.g. filter by type of message or updated date)


**Note**: Original author of this document is Natacha Beck