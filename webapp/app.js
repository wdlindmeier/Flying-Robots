var http = require('http');
var static = require('node-static');
var util = require('util');
var fs = require('fs');
var url = require("url");
var formidable = require('formidable');
var requestCheckin = false;

var webroot = './public'
var file = new(static.Server)(webroot, {
  cache: 0,
  headers: { 'X-Powered-By': 'node-static' }
});

var DisplaySocket = null;

var server = http.createServer(function(req, res) {
    // Simple path-based request dispatcher
	
	// console.log("New request "+url.parse(req.url).pathname);
	
    switch (url.parse(req.url).pathname) {
        case '/':
            display_form(req, res);
            break;
        case '/upload':
			upload_file(req, res);
            break;
        default:		
			// We'll just try to serve a flat-file.
			file.serve(req, res, function(err, result) {
		      if (err) {
		      	res.writeHead(404, {'Content-Type': 'text/plain'});
		      }
		      res.end();
		    });
            break;
    }
});

// Server would listen on port 8000
server.listen(8000);
var io = require('socket.io').listen(server);
io.set('log level', 1); // reduce logging

io.sockets.on('connection', function (socket) {

   console.log("NEW DISPLAY SOCKET");
   
   // Lets assume every connection is a display
   if(DisplaySocket && DisplaySocket != socket){
      DisplaySocket.disconnect(); 
   }
   
   DisplaySocket = socket;
   
   DisplaySocket.emit('connected_display', null);    

   socket.on('disconnect', function (reason) {      
       console.log("DISCONNECTING DISPLAY");        
       if(socket == DisplaySocket) DisplaySocket = null;	   
   });   
   
   socket.on('request_checkin', function(){
	   console.log("Requesting a checkin");
	   requestCheckin = true;
   });
   
});

function postImageToDisplay(fileInfo)
{    
    if(DisplaySocket) DisplaySocket.emit('received_image', fileInfo);    
}


function display_form(req, res) {
    res.writeHead(200, {"Content-Type": "text/html"});
    res.end(
        '<form action="/upload" method="post" enctype="multipart/form-data">'+
        '<input type="file" name="image">'+
        '<input type="submit" value="Upload">'+
        '</form>'
    );
}

function upload_file(req, res)
{
	if(req.method.toLowerCase() == 'post'){
		var form = new formidable.IncomingForm();
		form.uploadDir = './public/images';
		form.parse(req, function(err, fields, files) {
			// console.log("Upload received:");
			// Respond
			res.writeHead(201, {'Content-Type': 'text/plain'});
			if(requestCheckin){
				res.end("REQUEST_CHECKIN");
			}else{
				res.end();
			}
			requestCheckin = false;
			
			// Process the data
			// console.log(util.inspect({fields: fields, files: files}));
			/*
				{ fields: 
				   { lng: '-73.94644873223042',
				     lat: '40.71677280499529',
				     in_range: '0',
				     dist: '4027.226275545526' },
				  files: 
				   { image: 
				      { domain: null,
				        _events: {},
				        _maxListeners: 10,
				        size: 3875,
				        path: 'public/images/cc3c9f386e4216873a722667f33c8229',
				        name: 'image28.jpg',
				        type: 'image/jpeg',
				        hash: false,
				        lastModifiedDate: Sat Mar 23 2013 20:05:05 GMT-0400 (EDT),
				        _writeStream: [Object] } } }
			*/			
			f_info = files['image'];
			if(f_info){
				path_components = f_info.path.split('/');
				path_components[path_components.length - 1] = f_info.name;
				new_path = path_components.join('/');
				fs.rename(f_info.path, new_path);			
				// Send the new image path to the display
				image_path = new_path.replace('public', '');
				payload = { 'img_src' : image_path, 
							'in_range' : !!(fields.in_range * 1),
						    'dist' : fields.dist * 1,
							'lat' : fields.lat * 1,
							'lng' : fields.lng * 1,
							'checked_in' : !!(fields.checked_in * 1),
							'target_name' : fields.target_name
							}; 
				postImageToDisplay(payload);
			}
	    });
	}else{
		// Ignore non-post requests
		show_404(req, res);
	}
}

function show_404(req, res) {
    res.writeHead(404, {"Content-Type": "text/plain"});
    res.end("<html><body><h1>404 Not Found</h1></body></html>");
}