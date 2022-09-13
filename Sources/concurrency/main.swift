import Foundation

func operationQueueBasics() {
  // this acts as the arbiter of execution for many units of work:
  let operation = OperationQueue()
  
  operation.addOperation {
    print(Thread.current)
  }
  
  // similar to Threads, the order or execution is not guaranteed
  operation.addOperation { print("1", Thread.current) }
  operation.addOperation { print("2", Thread.current) }
  operation.addOperation { print("3", Thread.current) }
  operation.addOperation { print("4", Thread.current) }
  operation.addOperation { print("5", Thread.current) }
}

Thread.sleep(forTimeInterval: 2)
