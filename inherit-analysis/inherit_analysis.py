#-*- coding=utf8 -*-

from pprint import pprint

def analyse_method(obj):
    mro = obj.__class__.__mro__
    call_dict = {}
    for class_obj in mro:
        for att, att_obj in class_obj.__dict__.iteritems():
            if att.startswith("__"):
                continue
            if not hasattr(att_obj, "__call__"):
                continue
            call_list = call_dict.setdefault(att, [])
            call_list.append(class_obj)
    print "-"*12, "METHOD ANALYSE", "-"*12
    pprint(call_dict)

def analyse_call_wrap(obj):
    mro = obj.__class__.__mro__
    def wrap(fn, class_obj):
        def new_fn(*args, **kwargs):
            print "-"*12+">", class_obj, fn.__name__
            return fn(*args, **kwargs)
        new_fn.wrapped = True
        return new_fn
    for class_obj in mro:
        for att, att_obj in class_obj.__dict__.iteritems():
            if att.startswith("__"):
                continue
            if type(att_obj) != type(test):
                continue
            if getattr(att_obj, "wrapped", None):
                continue
            setattr(class_obj, att, wrap(att_obj, class_obj))

def test():
    class A(object):
        def a(self):
            pass
        def b(self):
            self.a()

    class B(A):
        def x(self):
            self.b()

        def b(self):
            super(B,self).b()

    #test1
    #obj = B()
    #analyse_method(obj)
    #obj = A()
    #analyse_method(obj)

    #test2
    obj = B()
    analyse_call_wrap(obj)
    obj.x()

if __name__ == "__main__":
    test()


