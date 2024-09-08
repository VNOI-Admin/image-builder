import urllib.parse as parse
import http.server as server

TEST_USER, TEST_PASSWORD = 'test-user', 'test-password'
TEST_ACCESS_TOKEN = 'test-access-token'
TEST_CONFIG_FILE_CONTENT = 'test-config-file-content VNOI ICPC'

class Handler(server.SimpleHTTPRequestHandler):
  def do_POST(self):
    """Only accept /login"""
    print("POST")
    if self.path != '/login':
      self.send_response(404)
      print('404')
      self.end_headers()
      return

    # Read the request body
    content_length = int(self.headers['Content-Length'])
    post_data = self.rfile.read(content_length)

    # Parse the request body
    parsed_post_data = parse.parse_qs(post_data.decode())
    print(parsed_post_data)
    username = parsed_post_data['username'][0]
    password = parsed_post_data['password'][0]

    # Check credentials
    if username == TEST_USER and password == TEST_PASSWORD:
      # Send back accessToken and refreshToken
      self.send_response(200)
      print('200')
      self.end_headers()

      response = '{"accessToken": "%s", "refreshToken": "%s"}' % (TEST_ACCESS_TOKEN, TEST_ACCESS_TOKEN)
      self.wfile.write(response.encode())
      print(response)
    else:
      self.send_response(401)
      print('401')
      self.end_headers()

  def do_GET(self):
    """Only accept /config"""
    print("GET")
    if self.path != '/config':
      self.send_response(404)
      print('404')
      self.end_headers()
      return

    # Check the access token
    print(self.headers)
    if self.headers['Authorization'] != 'Bearer %s' % TEST_ACCESS_TOKEN:
      self.send_response(401)
      print('401')
      self.end_headers()
      return

    # Send back the config
    self.send_response(200)
    print('200')
    self.end_headers()

    response = TEST_CONFIG_FILE_CONTENT
    self.wfile.write(response.encode())
    print(TEST_CONFIG_FILE_CONTENT)

if __name__ == '__main__':
  server.HTTPServer(('localhost', 8080), Handler).serve_forever()
