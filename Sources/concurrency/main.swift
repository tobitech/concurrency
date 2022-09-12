import Foundation

// It turns out threads are not started in the same way they were created.

func threadBasics() {
  Thread.detachNewThread {
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
}

let thread = Thread {
  // we work we do in this closure is lazy.
  
  // to demonstrate how long the Thread slept for
  let start = Date()
  defer { print("Finished in", Date().timeIntervalSince(start)) }
  
  // this doesn't perticipate in cooperative cancellation, so it will wait it full time even though it's cancelled.
  Thread.sleep(forTimeInterval: 1)
  
  // this is how co-operative cancellation works.
  
  guard !Thread.current.isCancelled else {
    print("Cancelled!")
    return
  }
  
  print(Thread.current) // print out what thread we're on.
}

// this allows us to set thread priority: a Double value between 0 and 1
// This will signal to the operating system that this thread is low or high priority, and perhaps the OS will give the thread a little bit less or more time to execute relative to other threads, though there are no guarantees.
thread.threadPriority = 0.75

// we need to explicitly start the thread since the work is lazy.
// otherwise the program exits immediately.
thread.start()

// this should give the thread just enough time to start execution
// otherwise the os just doesn't bother to start the thread since it was cancelled immediately.
Thread.sleep(forTimeInterval: 0.01)

// this allows us to cancel a thread
thread.cancel()

Thread.sleep(forTimeInterval: 1.1)
