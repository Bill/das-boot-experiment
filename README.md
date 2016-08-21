This is an experiment using Docker (layer management mechanism) to give traditional builds the same key efficiency optimization traditionally offered by make(1), namely: only run a build action if a target (dependency) is "out of date" relative to its sources. Docker layer management is superior to make's traditional mechanism because the former is content-based whereas the latter is timestamp-based. Timestamp-based approaches suffer many pitfalls.

## Try It

```
# first we build
$ docker build -t dbe .
# now inspect the output of the "link" step
$ docker run -it --rm --entrypoint cat dbe target/all.out
m1-f1
version 0
is compiled
m2-f1
version 0
is compiled
```

Hey that looks pretty good. Now edit m2/f1 to be:

```
m2-f1
version 1
```

And build again:

```
$ docker build -t dbe .
Sending build context to Docker daemon 9.216 kB
Step 1 : FROM alpine
 ---> 4e38e38c8ce0
Step 2 : WORKDIR /app
 ---> Using cache
 ---> 91e2ad08aa4d
Step 3 : COPY ./bin ./bin
 ---> Using cache
 ---> 398d047b0d47
Step 4 : ENV PATH ${PATH}:/app/bin
 ---> Using cache
 ---> 323a4f83bd29
Step 5 : COPY ./target ./target
 ---> Using cache
 ---> 7bf217425349
Step 6 : COPY ./m1 ./m1
 ---> Using cache
 ---> 4f0b9b74b140
Step 7 : RUN compile m1/f1.txt > target/m1-f1.out
 ---> Using cache
 ---> 149068820129
Step 8 : COPY ./m2 ./m2
 ---> 7b7a46f80a90
Removing intermediate container ca3a221ae9a6
Step 9 : RUN compile m2/f1.txt > target/m2-f1.out
 ---> Running in fe7f89aa5959
 ---> a5712e6b79b1
Removing intermediate container fe7f89aa5959
Step 10 : RUN link target/m1-f1.out target/m2-f1.out > target/all.out
 ---> Running in 4997d33153d5
 ---> 9c27d361775b
Removing intermediate container 4997d33153d5
Successfully built 9c27d361775b
```

Hey cool! See how Docker used cached images all the way up through step 7? And at step 8, because we COPY in a modified version of the m2 directory (it contains the modified `f1.txt` file) Docker notices that and builds a new layer for that step. All the rest of the steps build new layers as expected.

But all is not well. Try this now: edit m1/f1 to be:

```
m1-f1
version 1
```

Now we expect (hope) only the m1 compilation step and the link step to be re-run. Let's see:

```
$ docker build -t dbe .
Sending build context to Docker daemon 9.216 kB
Step 1 : FROM alpine
 ---> 4e38e38c8ce0
Step 2 : WORKDIR /app
 ---> Using cache
 ---> 91e2ad08aa4d
Step 3 : COPY ./bin ./bin
 ---> Using cache
 ---> 398d047b0d47
Step 4 : ENV PATH ${PATH}:/app/bin
 ---> Using cache
 ---> 323a4f83bd29
Step 5 : COPY ./target ./target
 ---> Using cache
 ---> 7bf217425349
Step 6 : COPY ./m1 ./m1
 ---> 1d8eb8eee5c8
Removing intermediate container d6554a38ea0d
Step 7 : RUN compile m1/f1.txt > target/m1-f1.out
 ---> Running in a3c42b405655
 ---> 1ffde8947986
Removing intermediate container a3c42b405655
Step 8 : COPY ./m2 ./m2
 ---> d99fa96c07d3
Removing intermediate container 017d17083ec6
Step 9 : RUN compile m2/f1.txt > target/m2-f1.out
 ---> Running in f89f3b56da59
 ---> 8e14cec45aca
Removing intermediate container f89f3b56da59
Step 10 : RUN link target/m1-f1.out target/m2-f1.out > target/all.out
 ---> Running in 5941e1cf15fb
 ---> 7ec938dce1e2
Removing intermediate container 5941e1cf15fb
Successfully built 7ec938dce1e2
```

As expected, Docker rebuilt the layers at steps 6,7, and 10. But unfortunately, it also rebuilt images at steps 8, and 9 as well. When building a Docker image (from a Dockerfile), once a line causes a cache miss, all subsequent lines do too.

This means a simple Dockerfile will not suffice and instead, if we want to leverage Docker's nifty filesystem magic, we'll have to explore a different approach. Maybe docker commit could help us. It'd be nice to not have to write Go code to access the image+layer manipulation primitives directly.
