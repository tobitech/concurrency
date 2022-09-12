import Foundation

// It turns out threads are not started in the same way they were created.
Thread.detachNewThread {
  // do some work
  // Thread.sleep(forTimeInterval: 1)
  // print(Thread.current)
  print("1", Thread.current)
}

Thread.detachNewThread {
  print("2", Thread.current)
}

Thread.detachNewThread {
  print("3", Thread.current)
}

Thread.detachNewThread {
  print("4", Thread.current)
}

Thread.detachNewThread {
  print("5", Thread.current)
}

// calling `Thread.sleep` is on the main thread of the executable application.
// call it inside the detachNewThread closure is sleeping on another thread different from the main thread of the application.
// print(Thread.current)
Thread.sleep(forTimeInterval: 1.1)
