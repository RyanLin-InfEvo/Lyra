import ctypes
import json
import os

# load shared library
so_file_path = './core/build/liblyra_core.so' 
lyra_lib = ctypes.CDLL(so_file_path)

lyra_lib.lyra_init.argtypes = [ctypes.c_char_p]
lyra_lib.lyra_init.restype = ctypes.c_int

# lyra_dispatch function
# input parameter list: c_char_p
lyra_lib.lyra_dispatch.argtypes = [ctypes.c_char_p]
# output parameter list: c_void_p
# c_void_p is a memory address
lyra_lib.lyra_dispatch.restype = ctypes.c_void_p 

# lyra_free_string function
# input parameter list: c_void_p
# output parameter list: None
lyra_lib.lyra_free_string.argtypes = [ctypes.c_void_p]
lyra_lib.lyra_free_string.restype = None


# -------------------------------------------------------------------------
# initialize database
# -------------------------------------------------------------------------
current_dir = os.getcwd().encode('utf-8')
init_result = lyra_lib.lyra_init(current_dir)
if init_result == 0:
    print("✅ Init database successfully!")
else:
    print("❌ Init database failed!")
    exit()


# -------------------------------------------------------------------------
# Send request 'CreateArtist' to C++
# -------------------------------------------------------------------------
request_dict = {
    "command": "CreateArtist",
    "params": {
        "uuid": "artist_uuid_jaychou_003",
        "name": "Jay AChou"
    }
}

# json.dumps will convert python dict to json string
request_str = json.dumps(request_dict, ensure_ascii=False)

# C++ cannot understand python string, we must encode it to C++ understandable string (bytes)
request_bytes = request_str.encode('utf-8')

print(f"📨 Python sending request: {request_str}")
print(f"📨 Python sending request(bytes): {request_bytes}")


# call C++ function
response_ptr = lyra_lib.lyra_dispatch(request_bytes)


# get response from C++ using pointer `response_ptr`
response_c_string = ctypes.cast(response_ptr, ctypes.c_char_p).value
print(f"📬 Python received response(bytes): {response_c_string}")

# decode C++ string to python string
response_str = response_c_string.decode('utf-8')
print(f"📬 Python received response: {response_str}")

# convert the received 'json string' to 'python dict'
response_dict = json.loads(response_str)
print("✨ Formated Response: ")
print(json.dumps(response_dict, indent=4, ensure_ascii=False))


# clean up memory at pointer `response_ptr`
lyra_lib.lyra_free_string(response_ptr)
print("🧹 C++ memory cleaned up")