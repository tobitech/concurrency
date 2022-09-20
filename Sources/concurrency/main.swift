import Foundation

// Let's suppose for a moment that Swift doesn't have for-loops but that it has a `jump` statement.
// We could replicate what for-loops give us by using jump statements.
// suppose we wanted to write a loop that printed all the even numbers between 0 and 100
func unstructuredProgramming() {
	//var x = 0
	//outer: var y = 0
	// this is how to label a statement, this one labelled as top.
	//top: if x.isMultiple(of: 2) {
	//	print(x)
	//}
	//inner: if x.isMultiple(of: 2) && y.isMultiple(of: 2) {
	//	print(x, y)
	//}
	//y += 1
	//if y <= 100 {
	//	continue inner
	//}
	//x += 1
	//if x <= 100 {
	// do a jump statement to go back to the isMultiple(:) line.
	//	continue outer
	//}
	
	// compared with for-loop
	for x in 0...100 {
		for y in 0...100 {
			if x.isMultiple(of: 2) && y.isMultiple(of: 2) {
				print(x, y)
			}
		}
	}
}

// And although Swift does not offer jump statements, at least not in the completely unfettered way that unstructured programming languages do,
// it does still have some tools that leave the world of fully structured programming.
// We’ve already even seen a few of these tools.
// example:
//print("Before")
//Thread.detachNewThread {
	// This creats an execution flow that is untethered from the execution flow that started it.
//	print(Thread.current)
//}
//print("After")

// The current thread prints after the "After" output.
// This clearly means that the code doesn't read from top to bottom
//Before
//After
//<NSThread: 0x1011059b0>{number = 2, name = (null)}

// This lack of top-to-bottom execution means that the tools we know and love from Swift are going to be subtly broken. For example, if we add a defer statement before spinning up the thread, then of course the defer is not going to execute when the thread finishes:
//func thread() {
//	defer { print("Finished") }
//	print("Before")
//	Thread.detachNewThread {
//
//		print(Thread.current)
//	}
//	print("After")
//}
//
//thread()

//Before
//After
//Finished
//<NSThread: 0x100707950>{number = 2, name = (null)}

// The same goes for lock.
// it is not guaranteed that we will be locked inside the thread’s execution:
func thread() {
	let lock = NSLock()
	lock.lock()
	defer { print("Finished") }
	print("Before")
	Thread.detachNewThread {
		
		print(Thread.current)
	}
	print("After")
	lock.unlock()
}

thread()

Thread.sleep(forTimeInterval: 2)
