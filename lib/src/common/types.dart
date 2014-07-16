part of plugins.common;

/**
 * The types of data that gets wrapped around the initial data
 * used for sending data across ports.
 */
class SendType {

  /**
   * Sent to plugins to tell them to quit properly.
   */
  static const int QUIT = 0;

  /**
   * Sends data normally to the plugin to handle.
   */
  static const int NORMAL = 1;

  /**
   * Sends a request to the plugin that expects data back.
   */
  static const int GET = 2;
}
