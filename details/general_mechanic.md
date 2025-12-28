## Before 1.0.4:
  Let's say, we need some files per operation (especially with Movie Makers)
  
  We have some input of such files on the node
  Operation costs some CPU clocks
  
  Our target - current_input*operation_cost
  
  If the node isn't a consumer, it will only receive leftovers
  If there's not enough CPU clock to satisfy all demand, we will multiply our target by supply/demand ratio (hardcoded to never be more than x1.0)

## 1.0.4+

  ### If there's enough supply to satisfy all demands, behaviour stays the same.
  ### When we dont have enough CPU speed:
  1. Locate all consumers connected
  2. Sort them in order from min to max-demand
  3. Go through sorted array, satisfying **FULL** demand of each consumer
  4. When single consumer demand gets bigger than resources remaining, satisfy only part of demand
     - for example, if it happened on the 4th consumers from the end of the list, it will get 1/4th of remaining speed
  5. When consumer line's demand stay roughly the same (don't bounce from 0 to something), start stabilizing
  6. With each tick, allocate average value between max demand and previously allocated value

  This approach provides production boost on CPU-heavy ***CONVEYOR-like*** lines up to \<nodes in line\>x times
