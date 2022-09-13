import Foundation

// for GCD, you think of concurrency in terms of queueus rather than in terms of threads.

// to start you start by creating a dispath queue.

let queue = DispatchQueue(label: "my.queue")

// then you can send units of work to the queue to be performed.
// this allows us to queue up some asynchronous work.
// by 
queue.async {
  print(Thread.current)
}

Thread.sleep(forTimeInterval: 2)
