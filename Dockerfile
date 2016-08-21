FROM alpine

WORKDIR /app

COPY ./bin ./bin

ENV PATH=${PATH}:/app/bin

COPY ./target ./target

# build module 1
COPY ./m1 ./m1
RUN compile m1/f1.txt > target/m1-f1.out

# build module 2
COPY ./m2 ./m2
RUN compile m2/f1.txt > target/m2-f1.out

# link the modules
RUN link target/m1-f1.out target/m2-f1.out > target/all.out
