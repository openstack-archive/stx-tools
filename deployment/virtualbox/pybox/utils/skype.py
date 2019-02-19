from skpy import Skype
from skpy import SkypeAuthException

sk = None
conversation = None
initialized = False

class InvalidDestination(Exception):
    pass
     
def init(username, password, destination):
    global sk, conversation, initialized
    if initialized:
        return
    sk = Skype(connect=False)
    sk.conn.setTokenFile("/tmp/{}-skype-token".format(username))
    try:
        sk.conn.readToken()
    except SkypeAuthException:
        sk.conn.setUserPwd(username, password)
        sk.conn.getSkypeToken()
    ch = sk.contacts[destination]
    if not ch:
        msg = "Destination user not found in Skype contacts: {}".format(destination)
        raise InvalidDestination(msg)
    conversation = sk.contacts[destination].chat
    initialized = True
    
def send_msg(msg):
    conversation.sendMsg(msg)
    
def send_file(filename):
    conversation.sendFile(open(filename, "rb"), filename)