import io
import struct
import sys

try:
    # Python 3
    from urllib.request import urlopen, Request
    from urllib.parse import urlencode
except ImportError:
    # Python 2
    from urllib2 import urlopen, Request
    from urllib import urlencode

try:
    xrange
except NameError:
    xrange = range

def to_byte(n):
    return bytes([n]) if sys.version_info[0] == 3 else chr(n)

def rc(x):
    start = 0
    for c in x:
        if sys.version_info[0] == 3:
            start ^= c
        else:
            start ^= ord(c)
    return to_byte(start)

def serial_keys(keys):
    if isinstance(keys, str):
        keys_b = keys.encode("ascii")
    else:
        keys_b = keys

    token = b'\x00\x05\x00\x00\x00\x00\x01'
    total_len = len(token) + len(keys_b) + 3

    data = b"".join([
        to_byte(total_len),
        token,
        to_byte(len(keys_b)),
        keys_b
    ])
    return data + rc(data)

def key_from_serial(data):
    token = b'\x00\x05\x00\x00\x00\x00\x01'
    total_len = data[0] if sys.version_info[0] == 3 else ord(data[0])
    key_len = total_len - len(token) - 3
    keys = data[-1 - key_len:-1]
    return keys

def open_sogou(keys, durtot=0, version='3.7'):
    url = 'http://shouji.sogou.com/web_ime/mobile.php?durtot=%d&h=000000000000000&r=store_mf_wandoujia&v=%s' % (durtot, version)
    data = serial_keys(keys)

    req = Request(url, data=data)
    return urlopen(req)

def get_base_url(durtot=0, version='3.7'):
    return 'http://shouji.sogou.com/web_ime/mobile.php?durtot=%d&h=000000000000000&r=store_mf_wandoujia&v=%s' % (durtot, version)

def parse_result(result):
    if not isinstance(result, (bytes, bytearray)):
        raise TypeError("result must be bytes")

    words = []

    if result[0] + 2 != len(result):
        print("Error: invalid size")
        return words

    num_words = struct.unpack('<H', result[0x12:0x14])[0]
    if num_words == 0 or num_words > 32:
        print("Warning: strange words num", num_words)

    pos = 0x14
    for i in xrange(num_words):
        str_len = struct.unpack('<H', result[pos:pos+2])[0]
        if str_len == 0 or str_len > 0xFF:
            raise ValueError(result)
        pos += 2
        if str_len == 0:
            continue

        word_bytes = result[pos:pos+str_len]
        word = word_bytes.decode('utf-16-le')

        try:
            word.encode('gb18030')
        except:
            print("Warning: word %s cant encode to gb18030" % repr(word))

        words.append(word)
        pos += str_len

        str_len = struct.unpack('<H', result[pos:pos+2])[0]
        pos += str_len + 2

        str_len = struct.unpack('<H', result[pos:pos+2])[0]
        pos += str_len + 2 + 1

    if pos != len(result):
        print("Warning: buffer not exhausted!")

    return words

def get_cloud_words(keys):
    res = open_sogou(keys)
    if hasattr(res, "code"):
        code = res.code
    else:
        code = res.getcode()

    if code != 200:
        print("Error: invalid response for input <%s>" % keys)
        return []

    result = res.read()
    return parse_result(result)

if __name__ == "__main__":
    # Python 3
    if sys.version_info >= (3, 0):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    # Python 2
    else:
        sys.stdout = io.open(sys.stdout.fileno(), 'w', encoding='utf-8')
    if len(sys.argv) > 1 and len(sys.argv[1]) > 0:
        matched_list = get_cloud_words(sys.argv[1])
        if matched_list:
            for matched_word in matched_list:
                print(matched_word)

