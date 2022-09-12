import Foundation

Thread.detachNewThread {
  // do some work
  Thread.sleep(forTimeInterval: 1)
  print(Thread.current)
}

// calling `Thread.sleep` is on the main thread of the executable application.
// call it inside the detachNewThread closure is sleeping on another thread different from the main thread of the application.
print(Thread.current)
Thread.sleep(forTimeInterval: 1.1)
