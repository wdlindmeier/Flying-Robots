function handler (req, res) {
  //console.log(req.url);
  fs.readFile(__dirname + '/'+req.url+'.html',
  function (err, data) {
    if (err) {
      res.writeHead(500);
      return res.end('Error loading index.html');
    }

    res.writeHead(200);
    res.end(data);
  });
}

var nodePositions = {};

var app = require('http').createServer(handler)
  , io = require('socket.io').listen(app)
  , fs = require('fs')

io.set('log level', 1); // reduce logging

//app.listen(3000);
app.listen(80);

function storeNodePosition(socket, data)
{
    nodePositions[socket.id] = data;
}

io.sockets.on('connection', function (socket) {
//  console.log(socket.id);
  //socket.emit('news', { hello: 'world' });
  socket.on('poll', function (data) {
    socket.emit('nodePos', { nodePositions : nodePositions });    
    nodePositions = {};    
  });
  socket.on('mousemove', function (data) {
      storeNodePosition(socket, data);
//      console.log(socket.id);
  });
  socket.on('touchmove', function (data) {
      storeNodePosition(socket, data);
//      console.log(socket.id);
  });
});