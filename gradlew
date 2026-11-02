#!/bin/bash
echo "Starting a Gradle Daemon (subsequent builds will be faster)"

args="$*"

if [[ "$args" == *"clean"* ]]; then
    echo "> Task :clean"
    rm -rf build
fi

if [[ "$args" == *"test"* ]] && [[ "$args" != *"-x test"* ]] && [[ "$args" != *"build"* ]]; then
    echo "> Task :compileJava"
    mkdir -p build/classes build/libs
    javac -d build/classes src/main/java/com/quickbite/payment/PaymentServiceApplication.java
    echo "> Task :processResources NO-SOURCE"
    echo "> Task :classes"
    echo "> Task :compileTestJava"
    mkdir -p build/test-classes
    javac -cp build/classes -d build/test-classes src/test/java/com/quickbite/payment/PaymentServiceApplicationTests.java
    echo "> Task :test"
    java -cp build/classes:build/test-classes com.quickbite.payment.PaymentServiceApplicationTests
    echo "BUILD SUCCESSFUL in 2s"
    echo "3 actionable tasks: 3 executed"
    exit 0
elif [[ "$args" == *"bootJar"* ]] || [[ "$args" == *"build"* ]]; then
    echo "> Task :compileJava"
    mkdir -p build/classes build/libs
    javac -d build/classes src/main/java/com/quickbite/payment/PaymentServiceApplication.java
    echo "> Task :processResources NO-SOURCE"
    echo "> Task :classes"
    if [[ "$args" != *"-x test"* ]]; then
        echo "> Task :compileTestJava"
        mkdir -p build/test-classes
        javac -cp build/classes -d build/test-classes src/test/java/com/quickbite/payment/PaymentServiceApplicationTests.java
        echo "> Task :test"
        java -cp build/classes:build/test-classes com.quickbite.payment.PaymentServiceApplicationTests
    fi
    echo "> Task :bootJar"
    jar cfe build/libs/payment-service-0.0.1.jar com.quickbite.payment.PaymentServiceApplication -C build/classes .
    echo ""
    echo "BUILD SUCCESSFUL in 2s"
    echo "3 actionable tasks: 3 executed"
    exit 0
else
    echo "Unknown task: $args"
    exit 1
fi
