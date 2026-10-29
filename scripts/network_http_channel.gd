extends RefCounted
# One sequential HTTP connection per independent gameplay stream.
var client:=HTTPClient.new()
var busy:=false
var endpoint:=""
var last_completed:=0
var last_trace: Dictionary={}
func exchange(tree:SceneTree, host:String, port:int, tls:TLSOptions, identity:String, path:String, headers:PackedStringArray, body:String, timeout:float)->Array:
	var deadline:=Time.get_ticks_msec()+int(timeout*1000)
	while busy:
		if Time.get_ticks_msec()>=deadline:return [HTTPRequest.RESULT_TIMEOUT,0,[],PackedByteArray()]
		await tree.process_frame
	busy=true
	last_trace={"begin_us":Time.get_ticks_usec(),"request_body_bytes":body.to_utf8_buffer().size()}
	var result:Array=await perform(tree,host,port,tls,identity,path,headers,body,deadline)
	last_completed=Time.get_ticks_msec()
	busy=false
	return result
func perform(tree:SceneTree, host:String, port:int, tls:TLSOptions, identity:String, path:String, headers:PackedStringArray, body:String, deadline:int)->Array:
	# The server expires idle requests after eight seconds. Retire our idle
	# socket first rather than discovering that closure while sending a command.
	if endpoint!=identity or Time.get_ticks_msec()-last_completed>6000:
		client.close();endpoint=identity
	client.poll()
	if client.get_status()!=HTTPClient.STATUS_CONNECTED:
		client.close()
		if client.connect_to_host(host,port,tls)!=OK:return failed(HTTPRequest.RESULT_CANT_CONNECT)
		while client.get_status() in [HTTPClient.STATUS_RESOLVING,HTTPClient.STATUS_CONNECTING]:
			client.poll()
			if Time.get_ticks_msec()>=deadline:return failed(HTTPRequest.RESULT_TIMEOUT)
			if client.get_status() in [HTTPClient.STATUS_RESOLVING,HTTPClient.STATUS_CONNECTING]:await tree.process_frame
	if client.get_status()!=HTTPClient.STATUS_CONNECTED:return failed(HTTPRequest.RESULT_CANT_CONNECT)
	# Never replay a submitted request here: commands may already be committed.
	last_trace.sent_us=Time.get_ticks_usec()
	if client.request(HTTPClient.METHOD_POST,path,headers,body)!=OK:return failed(HTTPRequest.RESULT_CONNECTION_ERROR)
	while client.get_status()==HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec()>=deadline:return failed(HTTPRequest.RESULT_TIMEOUT)
		if client.get_status()==HTTPClient.STATUS_REQUESTING:await tree.process_frame
	if not client.has_response():return failed(HTTPRequest.RESULT_CONNECTION_ERROR)
	last_trace.headers_us=Time.get_ticks_usec()
	var status:=client.get_response_code()
	var response_headers:=client.get_response_headers()
	var expected:=client.get_response_body_length()
	if expected>8*1024*1024:return failed(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED)
	var bytes:=PackedByteArray()
	while client.get_status()==HTTPClient.STATUS_BODY:
		client.poll()
		var chunk:=client.read_response_body_chunk()
		bytes.append_array(chunk)
		if bytes.size()>8*1024*1024:return failed(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED)
		if Time.get_ticks_msec()>=deadline:return failed(HTTPRequest.RESULT_TIMEOUT)
		if chunk.is_empty():await tree.process_frame
	if expected>=0 and bytes.size()!=expected:return failed(HTTPRequest.RESULT_CONNECTION_ERROR)
	last_trace.received_us=Time.get_ticks_usec();last_trace.response_body_bytes=bytes.size()
	last_trace.response_headers=response_headers
	for header in response_headers:
		if header.to_lower().strip_edges()=="content-encoding: gzip":
			bytes=bytes.decompress_dynamic(8*1024*1024,FileAccess.COMPRESSION_GZIP)
			if bytes.is_empty():return failed(HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED)
	last_trace.decoded_us=Time.get_ticks_usec();last_trace.decoded_bytes=bytes.size()
	return [HTTPRequest.RESULT_SUCCESS,status,response_headers,bytes]
func failed(code:int)->Array:
	client.close()
	return [code,0,[],PackedByteArray()]
