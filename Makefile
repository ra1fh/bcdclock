
SUBDIRS = src

all:
	@for dir in ${SUBDIRS}; do \
		echo "===> $${dir}"; \
		cd $${dir}; \
		exec ${MAKE} ${MAKE_FLAGS} all; \
	done

flash:
	@for dir in ${SUBDIRS}; do \
		echo "===> $${dir}"; \
		cd $${dir}; \
		exec ${MAKE} ${MAKE_FLAGS} flash; \
	done

sim:
	@for dir in ${SUBDIRS}; do \
		echo "===> $${dir}"; \
		cd $${dir}; \
		exec ${MAKE} ${MAKE_FLAGS} sim; \
	done

clean:
	@for dir in ${SUBDIRS}; do \
		echo "===> $${dir}"; \
		cd $${dir}; \
		exec ${MAKE} ${MAKE_FLAGS} clean; \
	done
