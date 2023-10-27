# sendingnetworkdart_api_lite

This package serves as a simple client-server data request interface with general-purpose API functions for interacting with the server. It doesn't include any specific business logic and doesn't handle client creation; instead, it focuses on providing fundamental API methods for server requests.

For more complex logic, you'll find it within the "sendingnetwork_dart_sdk." In most cases, using "sendingnetwork_dart_sdk" should suffice, as it's built on top of "sendingnetworkdart_api_lite." If, however, there is a need to create a client at the business logic level, you can directly rely on "sendingnetwork_dart_sdk."